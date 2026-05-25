import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/service/graph_traversal.dart';

import '../support/builders.dart';

void main() {
  group('GraphTraversal', () {
    // Tree shape used in most tests:
    //
    //         root
    //        /    \
    //     health   work
    //      |        |
    //   fitness  finish-phd
    //      |        |
    //   pushday  publish
    //                \
    //              llm-paper (helpful)
    late LakshyaGraph graph;
    setUp(() {
      graph = LakshyaGraph(
        nodes: [
          buildNode('root'),
          buildNode('health'),
          buildNode('work'),
          buildNode('fitness'),
          buildNode('finish-phd'),
          buildNode('pushday'),
          buildNode('publish'),
          buildNode('llm-paper'),
        ],
        edges: [
          buildEdge('e1', from: 'health', to: 'root'),
          buildEdge('e2', from: 'work', to: 'root'),
          buildEdge('e3', from: 'fitness', to: 'health'),
          buildEdge('e4', from: 'finish-phd', to: 'work'),
          buildEdge('e5', from: 'pushday', to: 'fitness'),
          buildEdge('e6', from: 'publish', to: 'finish-phd'),
          buildEdge('e7', from: 'llm-paper', to: 'publish', contribution: Contribution.helpful,
          ),
        ],
      );
    });

    test('descendantsOf walks the full subtree', () {
      final t = GraphTraversal(graph);
      expect(t.descendantsOf('work'),
          equals({'finish-phd', 'publish', 'llm-paper'}));
      expect(t.descendantsOf('health'), equals({'fitness', 'pushday'}));
    });

    test('descendantsOf excludes the goal itself', () {
      final t = GraphTraversal(graph);
      expect(t.descendantsOf('publish'), equals({'llm-paper'}));
      expect(t.descendantsOf('llm-paper'), isEmpty);
    });

    test('descendantsOf with mandatory contribution skips helpful edges', () {
      final t = GraphTraversal(graph);
      expect(
        t.descendantsOf('work', contribution: FilterContribution.mandatory),
        equals({'finish-phd', 'publish'}),
        reason: 'llm-paper is reached via a helpful edge, so excluded',
      );
    });

    test('descendantsOf with helpful contribution only follows helpful edges',
        () {
      final t = GraphTraversal(graph);
      expect(
        t.descendantsOf('work', contribution: FilterContribution.helpful),
        isEmpty,
        reason: 'no direct helpful edge from work',
      );
      expect(
        t.descendantsOf('publish', contribution: FilterContribution.helpful),
        equals({'llm-paper'}),
      );
    });

    test('ancestorsOf walks up through multiple parents', () {
      final multiParent = LakshyaGraph(
        nodes: [buildNode('a'), buildNode('b'), buildNode('c'), buildNode('shared')],
        edges: [
          buildEdge('e1', from: 'shared', to: 'a'),
          buildEdge('e2', from: 'shared', to: 'b'),
          buildEdge('e3', from: 'a', to: 'c'),
        ],
      );
      final t = GraphTraversal(multiParent);
      expect(t.ancestorsOf('shared'), equals({'a', 'b', 'c'}));
    });

    test('isLeafIn flags nodes with no children as leaves', () {
      final t = GraphTraversal(graph);
      expect(t.isLeafIn('pushday'), isTrue);
      expect(t.isLeafIn('llm-paper'), isTrue);
      expect(t.isLeafIn('health'), isFalse);
    });

    test('isLeafIn restricted to a scope respects scope membership', () {
      final t = GraphTraversal(graph);
      // health has children {fitness, pushday}, but if scope excludes them,
      // health becomes a leaf within the scope.
      expect(t.isLeafIn('health', scope: {'health', 'root'}), isTrue);
      expect(t.isLeafIn('health', scope: {'health', 'fitness'}), isFalse);
    });

    test('wouldFormCycle detects direct and transitive cycles', () {
      final t = GraphTraversal(graph);
      // Adding edge from root -> work would create a cycle (work is already
      // descendant of root via e2).
      expect(t.wouldFormCycle(childId: 'root', parentId: 'work'), isTrue);
      // Self-loops are cycles.
      expect(t.wouldFormCycle(childId: 'work', parentId: 'work'), isTrue);
      // Adding an edge to a non-descendant is fine.
      expect(t.wouldFormCycle(childId: 'pushday', parentId: 'work'), isFalse);
    });

    test('descendantsOf handles a node with multiple parents (DAG, not tree)',
        () {
      final shared = LakshyaGraph(
        nodes: [
          buildNode('root'),
          buildNode('a'),
          buildNode('b'),
          buildNode('shared'),
        ],
        edges: [
          buildEdge('e1', from: 'a', to: 'root'),
          buildEdge('e2', from: 'b', to: 'root'),
          buildEdge('e3', from: 'shared', to: 'a'),
          buildEdge('e4', from: 'shared', to: 'b'),
        ],
      );
      final t = GraphTraversal(shared);
      expect(t.descendantsOf('root'), equals({'a', 'b', 'shared'}));
    });

    test('wouldFormCycle detects cycles in a 10-node linear chain', () {
      final nodes = [
        for (var i = 0; i < 10; i++) buildNode('n$i'),
      ];
      final edges = [
        for (var i = 1; i < 10; i++)
          buildEdge('e$i', from: 'n$i', to: 'n${i - 1}'),
      ];
      final chain = LakshyaGraph(nodes: nodes, edges: edges);
      final t = GraphTraversal(chain);
      // n0 <- n1 <- n2 <- ... <- n9. Adding n0 -> n9 would cycle.
      expect(t.wouldFormCycle(childId: 'n0', parentId: 'n9'), isTrue);
      // Adding n9 -> n0 is already present direction — no NEW cycle.
      expect(t.wouldFormCycle(childId: 'n9', parentId: 'n0'), isFalse);
    });
  });
}
