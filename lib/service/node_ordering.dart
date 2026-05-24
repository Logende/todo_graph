import '../model/node.dart';
import '../model/node_relationship.dart';

/// Default value for [NodeOrdering.urgentWindow] — overridable per call site
/// (and at the document level via `Settings.urgentWindowDays`).
const Duration kDefaultUrgentWindow = Duration(days: 3);

/// Sorts nodes for display.
///
/// Two tiers:
///
/// 1. **Urgent**: nodes whose deadline is within [urgentWindow] of `now`.
///    Sorted by deadline ascending.
/// 2. **Everything else**: nodes with deadlines (sorted earliest first), then
///    impact descending, then createdAt ascending.
///
/// Importance relationships (`moreImportantThan` / `lessImportantThan`) act
/// as topological overrides applied AFTER the score-based sort, using the
/// score order to break ties. `alternativeTo` does not influence ordering —
/// it only cascades completion (handled in the controller).
class NodeOrdering {
  const NodeOrdering({this.urgentWindow = kDefaultUrgentWindow});

  final Duration urgentWindow;

  List<Node> defaultOrder(
    List<Node> nodes, {
    required DateTime now,
    List<NodeRelationship> relationships = const [],
  }) {
    if (nodes.isEmpty) return const [];

    final (urgent, rest) = _splitByUrgency(nodes, now);
    final orderedUrgent = [...urgent]..sort(_byDeadlineAsc);
    final orderedRest = [...rest]..sort(_byDeadlineThenImpactThenAge);

    final scoreOrder = [...orderedUrgent, ...orderedRest];
    if (relationships.isEmpty) return scoreOrder;

    return _applyImportanceRelationships(scoreOrder, relationships);
  }

  (List<Node> urgent, List<Node> rest) _splitByUrgency(
    List<Node> nodes,
    DateTime now,
  ) {
    final cutoff = now.add(urgentWindow);
    final urgent = <Node>[];
    final rest = <Node>[];
    for (final node in nodes) {
      if (node.deadline != null && !node.deadline!.isAfter(cutoff)) {
        urgent.add(node);
      } else {
        rest.add(node);
      }
    }
    return (urgent, rest);
  }

  int _byDeadlineAsc(Node a, Node b) =>
      _compareDeadline(a.deadline, b.deadline);

  int _byDeadlineThenImpactThenAge(Node a, Node b) {
    final cmpDeadline = _compareDeadline(a.deadline, b.deadline);
    if (cmpDeadline != 0) return cmpDeadline;
    final cmpImpact = _compareImpactDesc(a, b);
    if (cmpImpact != 0) return cmpImpact;
    return a.createdAt.compareTo(b.createdAt);
  }

  /// Compares two nullable deadlines. Nulls sink to the bottom.
  int _compareDeadline(DateTime? a, DateTime? b) {
    if (a != null && b != null) return a.compareTo(b);
    if (a != null) return -1;
    if (b != null) return 1;
    return 0;
  }

  int _compareImpactDesc(Node a, Node b) {
    final aw = a.impact?.weight ?? 0;
    final bw = b.impact?.weight ?? 0;
    return bw.compareTo(aw);
  }

  /// Topological sort by importance relationships, with [scoreOrder] used as
  /// the tiebreaker (Kahn's algorithm with a stable insertion order).
  List<Node> _applyImportanceRelationships(
    List<Node> scoreOrder,
    List<NodeRelationship> relationships,
  ) {
    final nodeById = {for (final n in scoreOrder) n.id: n};
    final indegree = <String, int>{for (final n in scoreOrder) n.id: 0};
    final children = <String, List<String>>{
      for (final n in scoreOrder) n.id: <String>[],
    };

    for (final relationship in relationships) {
      final pair = _directedAbovePair(relationship, nodeById.keys.toSet());
      if (pair == null) continue;
      children[pair.above]!.add(pair.below);
      indegree[pair.below] = indegree[pair.below]! + 1;
    }

    final position = <String, int>{
      for (var i = 0; i < scoreOrder.length; i++) scoreOrder[i].id: i,
    };
    int byPosition(String a, String b) => position[a]!.compareTo(position[b]!);

    final ready = <String>[
      for (final n in scoreOrder)
        if (indegree[n.id] == 0) n.id,
    ]..sort(byPosition);

    final result = <Node>[];
    final visited = <String>{};
    while (ready.isNotEmpty) {
      final id = ready.removeAt(0);
      if (!visited.add(id)) continue;
      result.add(nodeById[id]!);
      for (final downstream in children[id]!) {
        indegree[downstream] = indegree[downstream]! - 1;
        if (indegree[downstream] == 0) {
          _insertSorted(ready, downstream, byPosition);
        }
      }
    }

    if (result.length != scoreOrder.length) {
      // Conflicting constraints (cycle). Fall back to the score order.
      return scoreOrder;
    }
    return result;
  }

  void _insertSorted(
    List<String> sorted,
    String id,
    int Function(String, String) compare,
  ) {
    for (var i = 0; i < sorted.length; i++) {
      if (compare(id, sorted[i]) < 0) {
        sorted.insert(i, id);
        return;
      }
    }
    sorted.add(id);
  }

  /// Maps a relationship to a (above, below) pair when it constitutes a hard
  /// ordering constraint between two known nodes. Returns null for
  /// alternativeTo, self-loops, or references to unknown nodes.
  _AbovePair? _directedAbovePair(
    NodeRelationship relationship,
    Set<String> knownIds,
  ) {
    if (relationship.kind == RelationshipKind.alternativeTo) return null;
    if (!knownIds.contains(relationship.fromNodeId)) return null;
    if (!knownIds.contains(relationship.toNodeId)) return null;
    if (relationship.fromNodeId == relationship.toNodeId) return null;
    return switch (relationship.kind) {
      RelationshipKind.moreImportantThan => _AbovePair(
          above: relationship.fromNodeId,
          below: relationship.toNodeId,
        ),
      RelationshipKind.lessImportantThan => _AbovePair(
          above: relationship.toNodeId,
          below: relationship.fromNodeId,
        ),
      RelationshipKind.alternativeTo => null,
    };
  }
}

class _AbovePair {
  const _AbovePair({required this.above, required this.below});
  final String above;
  final String below;
}
