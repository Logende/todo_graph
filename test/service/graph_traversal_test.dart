import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/edge.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/graph_traversal.dart';

Node _node(String id) => Node(
      id: id,
      title: id,
      status: const AlwaysOnStatus(),
      createdAt: DateTime.utc(2026, 5, 24),
    );

Edge _edge(
  String id,
  String child,
  String parent, {
  Contribution contribution = Contribution.mandatory,
}) =>
    Edge(
      id: id,
      childId: child,
      parentId: parent,
      contribution: contribution,
    );

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
          _node('root'),
          _node('health'),
          _node('work'),
          _node('fitness'),
          _node('finish-phd'),
          _node('pushday'),
          _node('publish'),
          _node('llm-paper'),
        ],
        edges: [
          _edge('e1', 'health', 'root'),
          _edge('e2', 'work', 'root'),
          _edge('e3', 'fitness', 'health'),
          _edge('e4', 'finish-phd', 'work'),
          _edge('e5', 'pushday', 'fitness'),
          _edge('e6', 'publish', 'finish-phd'),
          _edge(
            'e7',
            'llm-paper',
            'publish',
            contribution: Contribution.helpful,
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
        nodes: [_node('a'), _node('b'), _node('c'), _node('shared')],
        edges: [
          _edge('e1', 'shared', 'a'),
          _edge('e2', 'shared', 'b'),
          _edge('e3', 'a', 'c'),
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
          _node('root'),
          _node('a'),
          _node('b'),
          _node('shared'),
        ],
        edges: [
          _edge('e1', 'a', 'root'),
          _edge('e2', 'b', 'root'),
          _edge('e3', 'shared', 'a'),
          _edge('e4', 'shared', 'b'),
        ],
      );
      final t = GraphTraversal(shared);
      expect(t.descendantsOf('root'), equals({'a', 'b', 'shared'}));
    });
  });
}
