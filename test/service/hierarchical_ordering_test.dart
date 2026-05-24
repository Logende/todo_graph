import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/impact.dart';
import 'package:lakshya/model/node_relationship.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/hierarchical_ordering.dart';

import '../support/builders.dart';

void main() {
  final now = DateTime.utc(2026, 5, 24, 12);
  const ordering = HierarchicalOrdering();

  group('HierarchicalOrdering', () {
    test('empty input returns empty', () {
      expect(
        ordering.arrange(
          nodes: const [],
          edges: const [],
          relationships: const [],
          now: now,
        ),
        isEmpty,
      );
    });

    test('flat nodes (no edges) appear at depth 0', () {
      final result = ordering.arrange(
        nodes: [buildNode('a'), buildNode('b')],
        edges: const [],
        relationships: const [],
        now: now,
      );
      expect(result.map((r) => r.depth), equals([0, 0]));
    });

    test('children are indented under their displayed parent', () {
      final result = ordering.arrange(
        nodes: [
          buildNode('root'),
          buildNode('child'),
          buildNode('grandchild'),
        ],
        edges: [
          buildEdge('e1', from: 'child', to: 'root'),
          buildEdge('e2', from: 'grandchild', to: 'child'),
        ],
        relationships: const [],
        now: now,
      );
      expect(result.map((r) => (r.node.id, r.depth)),
          equals([('root', 0), ('child', 1), ('grandchild', 2)]));
    });

    test(
        'top-level groups are ordered by their own deadline when set '
        '(parent-first rule)', () {
      final result = ordering.arrange(
        nodes: [
          buildNode('soonGroup', deadline: DateTime.utc(2026, 5, 25)),
          buildNode('laterGroup', deadline: DateTime.utc(2026, 7, 1)),
        ],
        edges: const [],
        relationships: const [],
        now: now,
      );
      expect(result.map((r) => r.node.id), equals(['soonGroup', 'laterGroup']));
    });

    test(
        'top-level group without own deadline inherits the earliest deadline '
        'in its filtered subtree', () {
      final result = ordering.arrange(
        nodes: [
          buildNode('healthGroup'),
          buildNode('urgentLeaf',
              status: NodeStatus.oneTime(),
              deadline: DateTime.utc(2026, 5, 25)),
          buildNode('workGroup'),
        ],
        edges: [
          buildEdge('e-leaf', from: 'urgentLeaf', to: 'healthGroup'),
        ],
        relationships: const [],
        now: now,
      );
      expect(
        result.where((r) => r.depth == 0).map((r) => r.node.id),
        equals(['healthGroup', 'workGroup']),
        reason:
            'healthGroup adopts its descendant urgent deadline so it ranks '
            'above workGroup which has nothing pressing',
      );
    });

    test(
        "parent's own deadline overrides children's deadline for ordering",
        () {
      // parentA has own deadline 6/30, child due tomorrow.
      // parentB has no own deadline, child due 6/5.
      // The user picked the "parent-first" variant: parentA uses its own
      // 6/30, parentB inherits 6/5, so parentB ranks first.
      final result = ordering.arrange(
        nodes: [
          buildNode('parentA', deadline: DateTime.utc(2026, 6, 30)),
          buildNode('leafA',
              status: NodeStatus.oneTime(),
              deadline: DateTime.utc(2026, 5, 25)),
          buildNode('parentB'),
          buildNode('leafB',
              status: NodeStatus.oneTime(),
              deadline: DateTime.utc(2026, 6, 5)),
        ],
        edges: [
          buildEdge('eA', from: 'leafA', to: 'parentA'),
          buildEdge('eB', from: 'leafB', to: 'parentB'),
        ],
        relationships: const [],
        now: now,
      );
      expect(result.where((r) => r.depth == 0).map((r) => r.node.id),
          equals(['parentB', 'parentA']));
    });

    test('impact inheritance is max-of-descendants when parent has none', () {
      final result = ordering.arrange(
        nodes: [
          buildNode('healthGroup'),
          buildNode('healthChild',
              status: NodeStatus.oneTime(), impact: Impact.critical),
          buildNode('workGroup'),
          buildNode('workChild',
              status: NodeStatus.oneTime(), impact: Impact.low),
        ],
        edges: [
          buildEdge('eh', from: 'healthChild', to: 'healthGroup'),
          buildEdge('ew', from: 'workChild', to: 'workGroup'),
        ],
        relationships: const [],
        now: now,
      );
      expect(result.where((r) => r.depth == 0).map((r) => r.node.id),
          equals(['healthGroup', 'workGroup']));
    });

    test('importance relationships override the score-based order per level',
        () {
      final result = ordering.arrange(
        nodes: [
          buildNode('a', impact: Impact.minimal),
          buildNode('b', impact: Impact.critical),
        ],
        edges: const [],
        relationships: const [
          NodeRelationship(
            id: 'r1',
            fromNodeId: 'a',
            toNodeId: 'b',
            kind: RelationshipKind.moreImportantThan,
          ),
        ],
        now: now,
      );
      expect(result.map((r) => r.node.id), equals(['a', 'b']));
    });

    test(
        'parent with multiple children aggregates the earliest deadline and '
        'the strongest impact across all of them', () {
      final result = ordering.arrange(
        nodes: [
          buildNode('parent'),
          buildNode('childA',
              status: NodeStatus.oneTime(),
              deadline: DateTime.utc(2026, 7, 1)),
          buildNode('childB',
              status: NodeStatus.oneTime(),
              deadline: DateTime.utc(2026, 5, 30),
              impact: Impact.high),
          buildNode('childC',
              status: NodeStatus.oneTime(),
              deadline: DateTime.utc(2026, 9, 1),
              impact: Impact.critical),
          // A second top-level node that should still rank below parent
          // because parent inherits 5/30 and Impact.critical from its
          // children.
          buildNode('competing',
              deadline: DateTime.utc(2026, 6, 30),
              impact: Impact.medium),
        ],
        edges: [
          buildEdge('e1', from: 'childA', to: 'parent'),
          buildEdge('e2', from: 'childB', to: 'parent'),
          buildEdge('e3', from: 'childC', to: 'parent'),
        ],
        relationships: const [],
        now: now,
      );
      expect(result.where((r) => r.depth == 0).map((r) => r.node.id),
          equals(['parent', 'competing']));
    });

    test('a node with two displayed parents is rendered once under each',
        () {
      final result = ordering.arrange(
        nodes: [
          buildNode('parentA'),
          buildNode('parentB'),
          buildNode('shared', status: NodeStatus.oneTime()),
        ],
        edges: [
          buildEdge('e1', from: 'shared', to: 'parentA'),
          buildEdge('e2', from: 'shared', to: 'parentB'),
        ],
        relationships: const [],
        now: now,
      );
      final sharedRows = result.where((r) => r.node.id == 'shared').toList();
      expect(sharedRows, hasLength(2));
      for (final row in sharedRows) {
        expect(row.depth, equals(1));
      }
    });
  });
}
