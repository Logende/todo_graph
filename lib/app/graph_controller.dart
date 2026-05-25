import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/contribution.dart';
import '../model/edge.dart';
import '../model/filter_preset.dart';
import '../model/impact.dart';
import '../model/lakshya_graph.dart';
import '../model/node.dart';
import '../model/node_relationship.dart';
import '../model/node_status.dart';
import '../model/settings.dart';
import '../service/clock.dart';
import '../service/graph_mutator.dart';
import '../service/id_generator.dart';

/// Owns the in-memory [LakshyaGraph], applies high-level user actions
/// (add node, mark complete, import, link), and persists the new graph
/// through the injected [save] callback. Notifies listeners after every
/// state change.
///
/// All mutation routes through [GraphMutator] so the DAG invariants stay
/// enforced regardless of which view triggered the change.
class GraphController extends ChangeNotifier {
  GraphController({
    required LakshyaGraph initial,
    required Future<void> Function(LakshyaGraph graph) save,
    required this.idGenerator,
    required this.clock,
    this.mutator = const GraphMutator(),
  })  : _graph = initial,
        // ignore: prefer_initializing_formals
        _save = save;

  Future<void> Function(LakshyaGraph graph) _save;

  /// Persists [graph] via the currently-active save callback. Re-bindable at
  /// runtime via [replaceSave] so the storage backend can be swapped after
  /// boot (e.g. user opts into file-system sync on the web).
  Future<void> save(LakshyaGraph graph) => _save(graph);

  /// Swaps the persistence target. The next call to [save] (and every
  /// controller-driven mutation thereafter) writes through [next].
  void replaceSave(Future<void> Function(LakshyaGraph graph) next) {
    _save = next;
  }

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
    Impact? impact,
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
      impact: impact,
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

  /// Removes a node and all incident edges and relationships.
  void deleteNode(String nodeId) {
    _updateAndPersist(mutator.deleteNode(_graph, nodeId));
  }

  /// Marks the node complete at the current clock reading. Cascades through
  /// `alternativeTo` relationships so closing one alternative closes its
  /// twins in the same action.
  void markCompleted(String nodeId) {
    final now = clock();
    final visited = <String>{};
    final pending = <String>[nodeId];
    var working = _graph;
    while (pending.isNotEmpty) {
      final currentId = pending.removeAt(0);
      if (!visited.add(currentId)) continue;
      working = _markOne(working, currentId, now);
      pending.addAll(_alternativesOf(working, currentId));
    }
    if (working != _graph) _updateAndPersist(working);
  }

  /// Re-opens a previously completed node. Unlike [markCompleted], this does
  /// not cascade through alternatives because re-opening one option should not
  /// silently re-open its siblings.
  void markIncomplete(String nodeId) {
    final now = clock();
    final next = _markOneIncomplete(_graph, nodeId, now);
    if (next != _graph) _updateAndPersist(next);
  }

  /// Sets the completion checkbox state explicitly.
  void setCompleted(String nodeId, {required bool isCompleted}) {
    if (isCompleted) {
      markCompleted(nodeId);
    } else {
      markIncomplete(nodeId);
    }
  }

  LakshyaGraph _markOne(LakshyaGraph graph, String nodeId, DateTime now) {
    final index = graph.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return graph;
    final node = graph.nodes[index];
    if (node.status.completion == null) return graph; // background goal
    final updated = node.copyWith(
      status: node.status.markCompletedAt(now),
      updatedAt: now,
    );
    return mutator.updateNode(graph, updated);
  }

  LakshyaGraph _markOneIncomplete(
    LakshyaGraph graph,
    String nodeId,
    DateTime now,
  ) {
    final index = graph.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return graph;
    final node = graph.nodes[index];
    if (node.status.completion == null) return graph;
    final updated = node.copyWith(
      status: node.status.markIncomplete(),
      updatedAt: now,
    );
    return mutator.updateNode(graph, updated);
  }

  Iterable<String> _alternativesOf(LakshyaGraph graph, String nodeId) {
    return graph.relationships
        .where((r) => r.kind == RelationshipKind.alternativeTo)
        .expand((r) sync* {
      if (r.fromNodeId == nodeId) yield r.toNodeId;
      if (r.toNodeId == nodeId) yield r.fromNodeId;
    });
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

  /// Moves the child edge from [fromParentId] to [toParentId], preserving the
  /// edge id and contribution. If the target parent already has the same
  /// child linked, the old edge is removed so the move still results in a
  /// single parent link there.
  void moveNodeToParent({
    required String childId,
    required String fromParentId,
    required String toParentId,
  }) {
    final edge = _graph.edges
        .where((e) => e.childId == childId && e.parentId == fromParentId)
        .firstOrNull;
    if (edge == null) {
      throw ArgumentError(
        'No edge exists from childId=$childId to parentId=$fromParentId',
      );
    }
    final next = mutator.reparentEdge(
      _graph,
      edgeId: edge.id,
      newParentId: toParentId,
    );
    if (next != _graph) _updateAndPersist(next);
  }

  /// Records an importance or alternative relationship between two nodes.
  /// See [RelationshipKind] for semantics.
  void addRelationship({
    required String fromNodeId,
    required String toNodeId,
    required RelationshipKind kind,
  }) {
    _updateAndPersist(
      mutator.addRelationship(
        _graph,
        NodeRelationship(
          id: idGenerator.next(),
          fromNodeId: fromNodeId,
          toNodeId: toNodeId,
          kind: kind,
        ),
      ),
    );
  }

  /// Removes a relationship by id.
  void removeRelationship(String relationshipId) {
    _updateAndPersist(
      mutator.removeRelationship(_graph, relationshipId),
    );
  }

  /// Records that [higherId] ranks above [lowerId] in the default ordering.
  ///
  /// Idempotent: a no-op when the relationship already exists in the
  /// requested direction. Cleans up any opposing relationship (the reverse
  /// `moreImportantThan` or the equivalent `lessImportantThan`) so the new
  /// statement is the only one between this pair.
  void setMoreImportantThan({
    required String higherId,
    required String lowerId,
  }) {
    if (higherId == lowerId) return;

    final conflicts = <NodeRelationship>[];
    var alreadyPresent = false;
    for (final r in _graph.relationships) {
      if (r.kind == RelationshipKind.alternativeTo) continue;
      if (r.kind == RelationshipKind.moreImportantThan &&
          r.fromNodeId == higherId &&
          r.toNodeId == lowerId) {
        alreadyPresent = true;
        continue;
      }
      final opposingMoreImportant =
          r.kind == RelationshipKind.moreImportantThan &&
              r.fromNodeId == lowerId &&
              r.toNodeId == higherId;
      final opposingLessImportant =
          r.kind == RelationshipKind.lessImportantThan &&
              ((r.fromNodeId == higherId && r.toNodeId == lowerId) ||
                  (r.fromNodeId == lowerId && r.toNodeId == higherId));
      if (opposingMoreImportant || opposingLessImportant) {
        conflicts.add(r);
      }
    }
    if (alreadyPresent && conflicts.isEmpty) return;

    var working = _graph;
    for (final r in conflicts) {
      working = mutator.removeRelationship(working, r.id);
    }
    if (!alreadyPresent) {
      working = mutator.addRelationship(
        working,
        NodeRelationship(
          id: idGenerator.next(),
          fromNodeId: higherId,
          toNodeId: lowerId,
          kind: RelationshipKind.moreImportantThan,
        ),
      );
    }
    _updateAndPersist(working);
  }

  /// Replaces the entire graph (used by "Import from JSON").
  void replaceWith(LakshyaGraph incoming) {
    _updateAndPersist(incoming);
  }

  /// Overwrites the saved dashboard tiles in one step. Used by the
  /// Manage Tiles screen for rename / delete / reorder operations.
  void setFilterPresets(List<FilterPreset> presets) {
    _updateAndPersist(_graph.copyWith(filterPresets: presets));
  }

  /// Replaces the document-level settings in one step.
  void updateSettings(Settings settings) {
    _updateAndPersist(_graph.copyWith(settings: settings));
  }

  /// Persists which nodes are collapsed in the hierarchical todo list view.
  void setCollapsedNodeIds(List<String> nodeIds) {
    final current = _graph.settings ?? const Settings();
    updateSettings(current.copyWith(collapsedNodeIds: nodeIds));
  }

  /// Broadcasts every error thrown by the [save] callback. The UI listens
  /// and surfaces them as a SnackBar / banner so the user finds out
  /// persistence failed instead of silently losing data.
  Stream<Object> get saveErrors => _saveErrors.stream;
  final StreamController<Object> _saveErrors =
      StreamController<Object>.broadcast();

  @override
  void dispose() {
    _saveErrors.close();
    super.dispose();
  }

  void _updateAndPersist(LakshyaGraph next) {
    _graph = next;
    notifyListeners();
    unawaited(_trySave(next));
  }

  Future<void> _trySave(LakshyaGraph graphToSave) async {
    try {
      await save(graphToSave);
    } catch (error, stackTrace) {
      debugPrint('Lakshya: save failed — $error\n$stackTrace');
      _saveErrors.add(error);
    }
  }
}
