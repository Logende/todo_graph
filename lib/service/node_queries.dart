import '../model/contribution.dart';
import '../model/impact.dart';
import '../model/lakshya_graph.dart';
import '../model/node.dart';
import '../model/node_relationship.dart';

/// Computed views over a single [LakshyaGraph]. Built once per graph and
/// consulted to answer "what do we know about this node, given its
/// neighbours and ancestry?" — the queries here look beyond the node's own
/// fields to its parents, descendants, and relationships.
///
/// Pre-builds adjacency tables so repeated lookups are O(parents/relationships)
/// rather than scanning the whole edge list each time.
class NodeQueries {
  NodeQueries(this.graph) {
    for (final edge in graph.edges) {
      (_parentsByChild[edge.childId] ??= <String>[]).add(edge.parentId);
      (_childrenByParent[edge.parentId] ??= <String>[]).add(edge.childId);
    }
    for (final node in graph.nodes) {
      _nodeById[node.id] = node;
    }
  }

  final LakshyaGraph graph;
  final Map<String, List<String>> _parentsByChild = {};
  final Map<String, List<String>> _childrenByParent = {};
  final Map<String, Node> _nodeById = {};

  /// Earliest deadline among the node itself and any of its (transitive)
  /// ancestors. `null` when no one in the chain has a deadline.
  DateTime? inheritedDeadline(String nodeId) {
    DateTime? earliest;
    _walkSelfAndAncestors(nodeId, (node) {
      earliest = _earlier(earliest, node.deadline);
    });
    return earliest;
  }

  /// Strongest impact among the node itself and any of its (transitive)
  /// ancestors.
  Impact? inheritedImpact(String nodeId) {
    Impact? strongest;
    _walkSelfAndAncestors(nodeId, (node) {
      strongest = _stronger(strongest, node.impact);
    });
    return strongest;
  }

  /// Ids of nodes that rank strictly above [nodeId] via an importance
  /// relationship. Considers both `moreImportantThan` (other -> self) and
  /// `lessImportantThan` (self -> other) since they're directional pairs.
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

  /// Ids of nodes that this node ranks strictly above. Mirror of
  /// [rankedAboveOf].
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

  /// Ids of nodes connected to [nodeId] via an `alternativeTo` relationship
  /// (regardless of stored direction).
  Set<String> alternativesOf(String nodeId) {
    final out = <String>{};
    for (final r in graph.relationships) {
      if (r.kind != RelationshipKind.alternativeTo) continue;
      if (r.fromNodeId == nodeId) out.add(r.toNodeId);
      if (r.toNodeId == nodeId) out.add(r.fromNodeId);
    }
    return out;
  }

  /// Ids of direct parents of [nodeId].
  List<String> directParentsOf(String nodeId) =>
      List.unmodifiable(_parentsByChild[nodeId] ?? const []);

  /// Ids of direct children of [nodeId].
  List<String> directChildrenOf(String nodeId) =>
      List.unmodifiable(_childrenByParent[nodeId] ?? const []);

  /// Ids of direct children that contribute to [nodeId] as mandatory AND are
  /// still ongoing at [now]. A non-empty result means [nodeId] should not be
  /// considered completable yet — its prerequisites aren't done.
  ///
  /// Background-goal children (no completion concept) are skipped: they
  /// never close, so blocking on them would mean a parent could never be
  /// ticked off.
  Set<String> openMandatoryChildrenOf(String nodeId, DateTime now) {
    final out = <String>{};
    for (final edge in graph.edges) {
      if (edge.parentId != nodeId) continue;
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
      final parents = _parentsByChild[current];
      if (parents != null) queue.addAll(parents);
    }
  }
}

DateTime? _earlier(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

Impact? _stronger(Impact? a, Impact? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.weight >= b.weight ? a : b;
}
