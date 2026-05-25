import '../model/edge.dart';
import '../model/impact.dart';
import '../model/node.dart';
import '../model/node_relationship.dart';
import 'node_ordering.dart';

import 'compare_utils.dart';
/// Arranges a list of nodes into an indented tree.
///
/// The tree's parent/child structure comes from [Edge]s whose endpoints are
/// both inside the filtered [nodes] set; nodes whose parents have been
/// filtered out float to the top level.
///
/// Per-level sibling ordering uses the same urgent-window heuristic as
/// [NodeOrdering], but with each row's *effective* deadline and impact: when
/// a parent has its own deadline/impact set, those win; otherwise we
/// aggregate the most-urgent values from the (filtered) descendants.
/// Importance relationships (`moreImportantThan` / `lessImportantThan`) that
/// connect two same-level siblings act as topological overrides.
///
/// Multi-parent nodes are emitted once under every parent that is present
/// in [nodes].
class HierarchicalOrdering {
  const HierarchicalOrdering({this.urgentWindow = kDefaultUrgentWindow});

  final Duration urgentWindow;

  List<HierarchicalRow> arrange({
    required List<Node> nodes,
    required List<Edge> edges,
    required List<NodeRelationship> relationships,
    required DateTime now,
  }) {
    if (nodes.isEmpty) return const [];

    final nodeById = {for (final n in nodes) n.id: n};
    final nodeIds = nodeById.keys.toSet();

    final childrenByParent = _displayChildrenByParent(edges, nodeIds);
    final parentsByChild = _displayParentsByChild(edges, nodeIds);
    final effective = _computeEffectiveScores(
      nodeById: nodeById,
      childrenByParent: childrenByParent,
    );

    final tops = nodes
        .where((n) => (parentsByChild[n.id] ?? const []).isEmpty)
        .toList(growable: false);

    final out = <HierarchicalRow>[];
    for (final root in _orderSiblings(
      siblings: tops,
      effective: effective,
      relationships: relationships,
      now: now,
    )) {
      _emit(
        node: root,
        depth: 0,
        pathPrefix: '',
        visited: {root.id},
        childrenByParent: childrenByParent,
        nodeById: nodeById,
        effective: effective,
        relationships: relationships,
        now: now,
        out: out,
      );
    }
    return out;
  }

  // --- effective-score aggregation -----------------------------------------

  Map<String, _Effective> _computeEffectiveScores({
    required Map<String, Node> nodeById,
    required Map<String, List<String>> childrenByParent,
  }) {
    final cache = <String, _Effective>{};
    _Effective compute(String id, Set<String> visiting) {
      final cached = cache[id];
      if (cached != null) return cached;
      if (!visiting.add(id)) {
        // Cycle defence (should never trigger for a DAG, but cheap to guard).
        return _Effective(deadline: null, impact: null);
      }
      final node = nodeById[id]!;
      var deadline = node.deadline;
      var impact = node.impact;
      if (deadline == null || impact == null) {
        DateTime? aggregatedDeadline;
        Impact? aggregatedImpact;
        for (final childId in childrenByParent[id] ?? const <String>[]) {
          final childEffective = compute(childId, {...visiting});
          aggregatedDeadline =
              earlierDate(aggregatedDeadline, childEffective.deadline);
          aggregatedImpact =
              strongerImpact(aggregatedImpact, childEffective.impact);
        }
        deadline ??= aggregatedDeadline;
        impact ??= aggregatedImpact;
      }
      final result = _Effective(deadline: deadline, impact: impact);
      cache[id] = result;
      return result;
    }

    for (final id in nodeById.keys) {
      compute(id, <String>{});
    }
    return cache;
  }

  // --- recursive emit -------------------------------------------------------

  void _emit({
    required Node node,
    required int depth,
    required String pathPrefix,
    required Set<String> visited,
    required Map<String, List<String>> childrenByParent,
    required Map<String, Node> nodeById,
    required Map<String, _Effective> effective,
    required List<NodeRelationship> relationships,
    required DateTime now,
    required List<HierarchicalRow> out,
  }) {
    final path = pathPrefix.isEmpty ? node.id : '$pathPrefix>${node.id}';
    out.add(HierarchicalRow(node: node, depth: depth, pathId: path));

    final childIds = childrenByParent[node.id] ?? const [];
    final visibleChildren = [
      for (final id in childIds)
        if (!visited.contains(id) && nodeById.containsKey(id))
          nodeById[id]!
    ];
    if (visibleChildren.isEmpty) return;

    final ordered = _orderSiblings(
      siblings: visibleChildren,
      effective: effective,
      relationships: relationships,
      now: now,
    );
    for (final child in ordered) {
      _emit(
        node: child,
        depth: depth + 1,
        pathPrefix: path,
        visited: {...visited, child.id},
        childrenByParent: childrenByParent,
        nodeById: nodeById,
        effective: effective,
        relationships: relationships,
        now: now,
        out: out,
      );
    }
  }

  // --- sibling sort + topological override ---------------------------------

  List<Node> _orderSiblings({
    required List<Node> siblings,
    required Map<String, _Effective> effective,
    required List<NodeRelationship> relationships,
    required DateTime now,
  }) {
    if (siblings.length <= 1) return siblings;

    // Wrap each sibling in a transient virtual node carrying its effective
    // deadline + impact, sort with the existing tiered algorithm, then map
    // back to the real Nodes. Reusing NodeOrdering keeps the urgent-window
    // semantics identical to the flat list view.
    final virtuals = [
      for (final n in siblings) _virtualWithEffective(n, effective[n.id]!),
    ];
    final virtualOrder = NodeOrdering(urgentWindow: urgentWindow)
        .defaultOrder(virtuals, now: now, relationships: relationships);
    final byId = {for (final n in siblings) n.id: n};
    return [for (final v in virtualOrder) byId[v.id]!];
  }

  Node _virtualWithEffective(Node real, _Effective effective) {
    // Reuse the Node type so NodeOrdering can sort us; only the fields the
    // ordering algorithm reads (deadline, impact, createdAt, id) are
    // load-bearing.
    return Node(
      id: real.id,
      title: real.title,
      status: real.status,
      createdAt: real.createdAt,
      deadline: effective.deadline,
      impact: effective.impact,
    );
  }
}

class HierarchicalRow {
  const HierarchicalRow({
    required this.node,
    required this.depth,
    required this.pathId,
  });

  final Node node;
  final int depth;

  /// Unique within the rendered tree even when [node] appears under multiple
  /// parents — useful as a widget key.
  final String pathId;
}

class _Effective {
  const _Effective({required this.deadline, required this.impact});
  final DateTime? deadline;
  final Impact? impact;
}

Map<String, List<String>> _displayChildrenByParent(
  List<Edge> edges,
  Set<String> nodeIds,
) {
  final out = <String, List<String>>{};
  for (final e in edges) {
    if (!nodeIds.contains(e.parentId)) continue;
    if (!nodeIds.contains(e.childId)) continue;
    (out[e.parentId] ??= <String>[]).add(e.childId);
  }
  return out;
}

Map<String, List<String>> _displayParentsByChild(
  List<Edge> edges,
  Set<String> nodeIds,
) {
  final out = <String, List<String>>{};
  for (final e in edges) {
    if (!nodeIds.contains(e.parentId)) continue;
    if (!nodeIds.contains(e.childId)) continue;
    (out[e.childId] ??= <String>[]).add(e.parentId);
  }
  return out;
}


