import '../model/contribution.dart';
import '../model/impact.dart';
import '../model/lakshya_graph.dart';
import '../model/node.dart';
import '../model/node_relationship.dart';
import 'compare_utils.dart';
import 'graph_traversal.dart';

/// Computed views over a single [LakshyaGraph]. Built once per graph and
/// consulted to answer "what do we know about this node, given its
/// neighbours and ancestry?" — the queries here look beyond the node's own
/// fields to its parents, descendants, and relationships.
///
/// Wraps a [GraphTraversal] for adjacency lookups so the edge-scanning work
/// is done only once even when both a traversal and queries are needed in
/// the same build cycle.
class NodeQueries {
  /// Creates a NodeQueries that builds its own [GraphTraversal] internally.
  NodeQueries(LakshyaGraph graph)
      : this.withTraversal(graph, GraphTraversal(graph));

  /// Creates a NodeQueries reusing an existing [GraphTraversal] so the
  /// adjacency maps are shared rather than rebuilt.
  NodeQueries.withTraversal(this.graph, this._traversal) {
    for (final node in graph.nodes) {
      _nodeById[node.id] = node;
    }
  }

  final LakshyaGraph graph;
  final GraphTraversal _traversal;
  final Map<String, Node> _nodeById = {};

  DateTime? inheritedDeadline(String nodeId) {
    DateTime? earliest;
    _walkSelfAndAncestors(nodeId, (node) {
      earliest = earlierDate(earliest, node.deadline);
    });
    return earliest;
  }

  Impact? inheritedImpact(String nodeId) {
    Impact? strongest;
    _walkSelfAndAncestors(nodeId, (node) {
      strongest = strongerImpact(strongest, node.impact);
    });
    return strongest;
  }

  Set<String> rankedAboveOf(String nodeId) {
    final out = <String>{};
    for (final r in graph.relationships) {
      if (r.kind == RelationshipKind.moreImportantThan &&
          r.toNodeId == nodeId) {
        out.add(r.fromNodeId);
      } else if (r.kind == RelationshipKind.lessImportantThan &&
          r.fromNodeId == nodeId) {
        out.add(r.toNodeId);
      }
    }
    return out;
  }

  Set<String> rankedBelowOf(String nodeId) {
    final out = <String>{};
    for (final r in graph.relationships) {
      if (r.kind == RelationshipKind.moreImportantThan &&
          r.fromNodeId == nodeId) {
        out.add(r.toNodeId);
      } else if (r.kind == RelationshipKind.lessImportantThan &&
          r.toNodeId == nodeId) {
        out.add(r.fromNodeId);
      }
    }
    return out;
  }

  Set<String> alternativesOf(String nodeId) {
    final out = <String>{};
    for (final r in graph.relationships) {
      if (r.kind != RelationshipKind.alternativeTo) continue;
      if (r.fromNodeId == nodeId) out.add(r.toNodeId);
      if (r.toNodeId == nodeId) out.add(r.fromNodeId);
    }
    return out;
  }

  List<String> directParentsOf(String nodeId) =>
      _traversal
          .outgoingEdgesFrom(nodeId)
          .map((e) => e.parentId)
          .toList(growable: false);

  List<String> directChildrenOf(String nodeId) =>
      _traversal
          .incomingEdgesTo(nodeId)
          .map((e) => e.childId)
          .toList(growable: false);

  Set<String> openMandatoryChildrenOf(String nodeId, DateTime now) {
    final out = <String>{};
    for (final edge in _traversal.incomingEdgesTo(nodeId)) {
      if (edge.contribution != Contribution.mandatory) continue;
      final child = _nodeById[edge.childId];
      if (child == null) continue;
      if (child.status.completion == null) continue;
      if (child.status.isOngoingAt(now)) out.add(child.id);
    }
    return out;
  }

  void _walkSelfAndAncestors(String startId, void Function(Node) visit) {
    final visited = <String>{};
    final queue = <String>[startId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visited.add(current)) continue;
      final node = _nodeById[current];
      if (node == null) continue;
      visit(node);
      for (final edge in _traversal.outgoingEdgesFrom(current)) {
        queue.add(edge.parentId);
      }
    }
  }
}
