import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/contribution.dart';
import '../model/edge.dart';
import '../model/lakshya_graph.dart';
import '../model/node.dart';
import '../model/node_status.dart';
import '../service/graph_initializer.dart' show Clock;
import '../service/graph_mutator.dart';
import '../service/id_generator.dart';

/// Owns the in-memory [LakshyaGraph], applies high-level user actions
/// (add node, mark complete, import), and persists the new graph through the
/// injected [save] callback. Notifies listeners after every state change.
///
/// All mutation routes through [GraphMutator] so the DAG invariants stay
/// enforced regardless of which view triggered the change.
class GraphController extends ChangeNotifier {
  GraphController({
    required LakshyaGraph initial,
    required this.save,
    required this.idGenerator,
    required this.clock,
    this.mutator = const GraphMutator(),
  }) : _graph = initial;

  final Future<void> Function(LakshyaGraph graph) save;
  final IdGenerator idGenerator;
  final Clock clock;
  final GraphMutator mutator;

  LakshyaGraph _graph;
  LakshyaGraph get graph => _graph;

  /// Adds a new node and an edge linking it as a child of [parentId].
  ///
  /// Returns the newly-created node so the UI can navigate or focus it.
  Node addChildNode({
    required String title,
    required String parentId,
    required NodeStatus status,
    String? description,
    double? priority,
    double? positiveImpact,
    DateTime? deadline,
    Contribution contribution = Contribution.mandatory,
  }) {
    final now = clock();
    final node = Node(
      id: idGenerator.next(),
      title: title,
      status: status,
      createdAt: now,
      description: description,
      priority: priority,
      positiveImpact: positiveImpact,
      deadline: deadline,
    );
    final withNode = mutator.addNode(_graph, node);
    final withEdge = mutator.addEdge(
      withNode,
      Edge(
        id: idGenerator.next(),
        childId: node.id,
        parentId: parentId,
        contribution: contribution,
      ),
    );
    _updateAndPersist(withEdge);
    return node;
  }

  /// Replaces a node by id.
  void updateNode(Node updated) {
    _updateAndPersist(mutator.updateNode(_graph, updated));
  }

  /// Removes a node and all incident edges.
  void deleteNode(String nodeId) {
    _updateAndPersist(mutator.deleteNode(_graph, nodeId));
  }

  /// Marks the node complete at the current clock reading.
  void markCompleted(String nodeId) {
    final index = _graph.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return;
    final node = _graph.nodes[index];
    final updated = Node(
      id: node.id,
      title: node.title,
      status: node.status.markCompletedAt(clock()),
      createdAt: node.createdAt,
      description: node.description,
      priority: node.priority,
      positiveImpact: node.positiveImpact,
      deadline: node.deadline,
      attachments: node.attachments,
      notificationOverride: node.notificationOverride,
      updatedAt: clock(),
    );
    _updateAndPersist(mutator.updateNode(_graph, updated));
  }

  /// Adds an extra parent for an existing node.
  void addEdge({
    required String childId,
    required String parentId,
    Contribution contribution = Contribution.mandatory,
  }) {
    _updateAndPersist(
      mutator.addEdge(
        _graph,
        Edge(
          id: idGenerator.next(),
          childId: childId,
          parentId: parentId,
          contribution: contribution,
        ),
      ),
    );
  }

  /// Removes an edge by id.
  void removeEdge(String edgeId) {
    _updateAndPersist(mutator.removeEdge(_graph, edgeId));
  }

  /// Replaces the entire graph (used by "Import from JSON").
  void replaceWith(LakshyaGraph incoming) {
    _updateAndPersist(incoming);
  }

  void _updateAndPersist(LakshyaGraph next) {
    _graph = next;
    notifyListeners();
    unawaited(save(next));
  }
}
