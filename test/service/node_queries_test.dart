import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/impact.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node_relationship.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/node_queries.dart';

import '../support/builders.dart';

void main() {
  group('NodeQueries.inheritedDeadline', () {
    test('returns the node own deadline when set', () {
      final graph = LakshyaGraph(
        nodes: [
          buildNode('child',
              status: NodeStatus.oneTime(),
              deadline: DateTime.utc(2026, 5, 25)),
        ],
        edges: const [],
      );
      expect(
        NodeQueries(graph).inheritedDeadline('child'),
        equals(DateTime.utc(2026, 5, 25)),
      );
    });

    test("falls back to the earliest ancestor's deadline when own is unset",
        () {
      final graph = LakshyaGraph(
        nodes: [
          buildNode('grandparent',
              deadline: DateTime.utc(2026, 12, 1)),
          buildNode('parent', deadline: DateTime.utc(2026, 6, 30)),
          buildNode('child', status: NodeStatus.oneTime()),
        ],
        edges: [
          buildEdge('e1', from: 'parent', to: 'grandparent'),
          buildEdge('e2', from: 'child', to: 'parent'),
        ],
      );
      expect(
        NodeQueries(graph).inheritedDeadline('child'),
        equals(DateTime.utc(2026, 6, 30)),
      );
    });

    test('combines own and ancestor deadlines, taking the earliest', () {
      final graph = LakshyaGraph(
        nodes: [
          buildNode('parent', deadline: DateTime.utc(2026, 5, 30)),
          buildNode('child',
              status: NodeStatus.oneTime(),
              deadline: DateTime.utc(2026, 6, 15)),
        ],
        edges: [buildEdge('e1', from: 'child', to: 'parent')],
      );
      expect(
        NodeQueries(graph).inheritedDeadline('child'),
        equals(DateTime.utc(2026, 5, 30)),
      );
    });

    test('returns null when neither self nor any ancestor has a deadline', () {
      final graph = LakshyaGraph(
        nodes: [
          buildNode('parent'),
          buildNode('child', status: NodeStatus.oneTime()),
        ],
        edges: [buildEdge('e1', from: 'child', to: 'parent')],
      );
      expect(NodeQueries(graph).inheritedDeadline('child'), isNull);
    });
  });

  group('NodeQueries.inheritedImpact', () {
    test('returns the strongest impact across self and ancestors', () {
      final graph = LakshyaGraph(
        nodes: [
          buildNode('parent', impact: Impact.critical),
          buildNode('child',
              status: NodeStatus.oneTime(), impact: Impact.low),
        ],
        edges: [buildEdge('e1', from: 'child', to: 'parent')],
      );
      expect(
        NodeQueries(graph).inheritedImpact('child'),
        equals(Impact.critical),
      );
    });

    test('falls back to ancestor when own is unset', () {
      final graph = LakshyaGraph(
        nodes: [
          buildNode('parent', impact: Impact.high),
          buildNode('child', status: NodeStatus.oneTime()),
        ],
        edges: [buildEdge('e1', from: 'child', to: 'parent')],
      );
      expect(
        NodeQueries(graph).inheritedImpact('child'),
        equals(Impact.high),
      );
    });
  });

  group('NodeQueries relationship lookups', () {
    final graph = LakshyaGraph(
      nodes: [buildNode('a'), buildNode('b'), buildNode('c'), buildNode('d')],
      edges: const [],
      relationships: const [
        NodeRelationship(
          id: 'r1',
          fromNodeId: 'a',
          toNodeId: 'b',
          kind: RelationshipKind.moreImportantThan,
        ),
        NodeRelationship(
          id: 'r2',
          fromNodeId: 'b',
          toNodeId: 'c',
          kind: RelationshipKind.lessImportantThan,
        ),
        NodeRelationship(
          id: 'r3',
          fromNodeId: 'a',
          toNodeId: 'd',
          kind: RelationshipKind.alternativeTo,
        ),
      ],
    );

    test('rankedAboveOf returns ids that outrank the node', () {
      final queries = NodeQueries(graph);
      // moreImportantThan(a, b): a above b.
      // lessImportantThan(b, c): c above b.
      expect(queries.rankedAboveOf('b'), equals({'a', 'c'}));
    });

    test('rankedBelowOf returns ids that the node outranks', () {
      final queries = NodeQueries(graph);
      // a moreImportantThan b => b below a.
      // No other directional touching a.
      expect(queries.rankedBelowOf('a'), equals({'b'}));
    });

    test('alternativesOf returns symmetric alternativeTo partners', () {
      final queries = NodeQueries(graph);
      expect(queries.alternativesOf('a'), equals({'d'}));
      expect(queries.alternativesOf('d'), equals({'a'}));
      expect(queries.alternativesOf('b'), isEmpty);
    });
  });

  group('NodeQueries.openMandatoryChildrenOf', () {
    final now = DateTime.utc(2026, 5, 24, 12);

    test('returns mandatory children that are still ongoing', () {
      final graph = LakshyaGraph(
        nodes: [
          buildNode('parent', status: NodeStatus.oneTime()),
          buildNode('child', status: NodeStatus.oneTime()),
        ],
        edges: [buildEdge('e1', from: 'child', to: 'parent')],
      );
      expect(NodeQueries(graph).openMandatoryChildrenOf('parent', now),
          equals({'child'}));
    });

    test('skips completed mandatory children', () {
      final graph = LakshyaGraph(
        nodes: [
          buildNode('parent', status: NodeStatus.oneTime()),
          buildNode('child',
              status: NodeStatus.oneTime(completedAt: now)),
        ],
        edges: [buildEdge('e1', from: 'child', to: 'parent')],
      );
      expect(NodeQueries(graph).openMandatoryChildrenOf('parent', now),
          isEmpty);
    });

    test('skips helpful children', () {
      final graph = LakshyaGraph(
        nodes: [
          buildNode('parent', status: NodeStatus.oneTime()),
          buildNode('helpful', status: NodeStatus.oneTime()),
        ],
        edges: [
          buildEdge('e1',
              from: 'helpful',
              to: 'parent',
              contribution: Contribution.helpful),
        ],
      );
      expect(NodeQueries(graph).openMandatoryChildrenOf('parent', now),
          isEmpty);
    });

    test('skips background-goal children (they never close)', () {
      final graph = LakshyaGraph(
        nodes: [
          buildNode('parent', status: NodeStatus.oneTime()),
          buildNode('alwaysOnChild'),
        ],
        edges: [buildEdge('e1', from: 'alwaysOnChild', to: 'parent')],
      );
      expect(NodeQueries(graph).openMandatoryChildrenOf('parent', now),
          isEmpty);
    });
  });
}
