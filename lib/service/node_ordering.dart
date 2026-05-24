import '../model/node.dart';
import '../model/priority_pin.dart';

/// Sorts nodes for display.
///
/// The default ordering is: deadline ascending (nodes without a deadline last),
/// then priority descending, then positiveImpact descending, then createdAt
/// ascending as a stable tiebreaker.
///
/// Manual [PriorityPin]s then override the result by forcing each `higherId`
/// to appear before its `lowerId`. Pins referencing nodes that are not in the
/// input list are ignored. Pins are applied via a topological sort, falling
/// back to the default order to break ties.
class NodeOrdering {
  const NodeOrdering();

  List<Node> defaultOrder(
    List<Node> nodes, {
    List<PriorityPin> priorityPins = const [],
  }) {
    if (nodes.isEmpty) return const [];

    final sorted = [...nodes]..sort(_compareDefault);

    if (priorityPins.isEmpty) return sorted;

    return _applyPins(sorted, priorityPins);
  }

  int _compareDefault(Node a, Node b) {
    // Deadline: earlier first; nodes without a deadline sink to the bottom.
    final ad = a.deadline;
    final bd = b.deadline;
    if (ad != null && bd != null) {
      final cmp = ad.compareTo(bd);
      if (cmp != 0) return cmp;
    } else if (ad != null) {
      return -1;
    } else if (bd != null) {
      return 1;
    }

    final cmpPriority = _compareDescending(a.priority, b.priority);
    if (cmpPriority != 0) return cmpPriority;

    final cmpImpact =
        _compareDescending(a.positiveImpact, b.positiveImpact);
    if (cmpImpact != 0) return cmpImpact;

    return a.createdAt.compareTo(b.createdAt);
  }

  /// Compares two nullable doubles, descending. Nulls sink to the bottom.
  int _compareDescending(double? a, double? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  /// Topological sort by pin constraints, with the existing [order] used to
  /// break ties (Kahn's algorithm with a stable tiebreaker).
  List<Node> _applyPins(List<Node> order, List<PriorityPin> pins) {
    final nodeById = {for (final n in order) n.id: n};
    final indegree = <String, int>{for (final n in order) n.id: 0};
    final children = <String, List<String>>{
      for (final n in order) n.id: <String>[],
    };

    for (final pin in pins) {
      if (!nodeById.containsKey(pin.higherId)) continue;
      if (!nodeById.containsKey(pin.lowerId)) continue;
      if (pin.higherId == pin.lowerId) continue;
      children[pin.higherId]!.add(pin.lowerId);
      indegree[pin.lowerId] = indegree[pin.lowerId]! + 1;
    }

    // Position in the default order — earlier index wins ties.
    final position = <String, int>{
      for (var i = 0; i < order.length; i++) order[i].id: i,
    };
    int byPosition(String a, String b) => position[a]!.compareTo(position[b]!);

    final ready = <String>[
      for (final n in order)
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
          // Insert keeping ready sorted by default position.
          var insertAt = ready.length;
          for (var i = 0; i < ready.length; i++) {
            if (byPosition(downstream, ready[i]) < 0) {
              insertAt = i;
              break;
            }
          }
          ready.insert(insertAt, downstream);
        }
      }
    }

    if (result.length != order.length) {
      // Conflict (pin cycle). Fall back to the default order, ignoring pins.
      return order;
    }
    return result;
  }
}
