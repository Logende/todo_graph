import '../model/contribution.dart';
import '../model/edge.dart';
import '../model/lakshya_graph.dart';

/// Pure-functional traversal queries on a [LakshyaGraph].
///
/// Built once per graph so adjacency lookups for repeated queries are O(1)
/// instead of scanning the whole edges list every time.
class GraphTraversal {
  GraphTraversal(LakshyaGraph graph) : _graph = graph {
    for (final edge in graph.edges) {
      (_childrenByParent[edge.parentId] ??= <Edge>[]).add(edge);
      (_parentsByChild[edge.childId] ??= <Edge>[]).add(edge);
    }
  }

  final LakshyaGraph _graph;
  final Map<String, List<Edge>> _childrenByParent = {};
  final Map<String, List<Edge>> _parentsByChild = {};

  /// Edges where [parentId] is the parent (i.e. children pointing up to it).
  List<Edge> incomingEdgesTo(String parentId) =>
      _childrenByParent[parentId] ?? const [];

  /// Edges from [childId] to its parents.
  List<Edge> outgoingEdgesFrom(String childId) =>
      _parentsByChild[childId] ?? const [];

  /// IDs of all descendants of [goalId], not including [goalId] itself.
  ///
  /// When [contribution] is set to a specific kind (mandatory or helpful),
  /// only edges of that kind are followed. [FilterContribution.any] follows
  /// both.
  Set<String> descendantsOf(
    String goalId, {
    FilterContribution contribution = FilterContribution.any,
  }) {
    final visited = <String>{};
    final stack = <String>[goalId];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final edge in incomingEdgesTo(current)) {
        if (!_matchesContribution(edge.contribution, contribution)) continue;
        if (visited.add(edge.childId)) {
          stack.add(edge.childId);
        }
      }
    }
    return visited;
  }

  /// IDs of all ancestors of [nodeId], not including [nodeId] itself.
  Set<String> ancestorsOf(String nodeId) {
    final visited = <String>{};
    final stack = <String>[nodeId];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final edge in outgoingEdgesFrom(current)) {
        if (visited.add(edge.parentId)) {
          stack.add(edge.parentId);
        }
      }
    }
    return visited;
  }

  /// True when [nodeId] has no children inside [scope]. Scope defaults to the
  /// full graph so [isLeafIn] with no argument means "leaf in the whole DAG".
  bool isLeafIn(String nodeId, {Set<String>? scope}) {
    final children = incomingEdgesTo(nodeId);
    if (children.isEmpty) return true;
    if (scope == null) return false;
    for (final edge in children) {
      if (scope.contains(edge.childId)) return false;
    }
    return true;
  }

  /// True when adding an edge from [childId] to [parentId] would create a
  /// cycle (parent reachable from child going downward).
  bool wouldFormCycle({required String childId, required String parentId}) {
    if (childId == parentId) return true;
    return descendantsOf(childId).contains(parentId);
  }

  /// Convenience: the underlying graph.
  LakshyaGraph get graph => _graph;

  static bool _matchesContribution(
    Contribution edge,
    FilterContribution selector,
  ) {
    return switch (selector) {
      FilterContribution.any => true,
      FilterContribution.mandatory => edge == Contribution.mandatory,
      FilterContribution.helpful => edge == Contribution.helpful,
    };
  }
}
