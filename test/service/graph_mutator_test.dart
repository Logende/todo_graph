import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/edge.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/graph_mutator.dart';

Node _n(String id) => Node(
      id: id,
      title: id,
      status: const AlwaysOnStatus(),
      createdAt: DateTime.utc(2026, 5, 24),
    );

Edge _e(String id, String child, String parent) => Edge(
      id: id,
      childId: child,
      parentId: parent,
      contribution: Contribution.mandatory,
    );

void main() {
  group('GraphMutator', () {
    const mutator = GraphMutator();

    test('addNode appends without touching edges', () {
      final start = LakshyaGraph(nodes: [_n('a')], edges: const []);
      final next = mutator.addNode(start, _n('b'));
      expect(next.nodes.map((n) => n.id), equals(['a', 'b']));
      expect(next.edges, isEmpty);
    });

    test('addNode rejects duplicate ids', () {
      final start = LakshyaGraph(nodes: [_n('a')], edges: const []);
      expect(() => mutator.addNode(start, _n('a')),
          throwsA(isA<ArgumentError>()));
    });

    test('updateNode replaces by id and keeps node order', () {
      final start = LakshyaGraph(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: const [],
      );
      final updated = Node(
        id: 'b',
        title: 'B-updated',
        status: const OneTimeStatus(),
        createdAt: DateTime.utc(2026, 5, 24),
      );
      final next = mutator.updateNode(start, updated);
      expect(next.nodes.map((n) => n.id), equals(['a', 'b', 'c']));
      expect(next.nodes[1].title, equals('B-updated'));
    });

    test('updateNode throws when the id is not present', () {
      final start = LakshyaGraph(nodes: [_n('a')], edges: const []);
      expect(() => mutator.updateNode(start, _n('ghost')),
          throwsA(isA<ArgumentError>()));
    });

    test('deleteNode removes the node and all incident edges', () {
      final start = LakshyaGraph(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [_e('e1', 'b', 'a'), _e('e2', 'c', 'b')],
      );
      final next = mutator.deleteNode(start, 'b');
      expect(next.nodes.map((n) => n.id), equals(['a', 'c']));
      expect(next.edges, isEmpty);
    });

    test('deleteNode throws when the id is not present', () {
      final start = LakshyaGraph(nodes: const [], edges: const []);
      expect(() => mutator.deleteNode(start, 'ghost'),
          throwsA(isA<ArgumentError>()));
    });

    test('addEdge appends and rejects duplicates by id', () {
      final start = LakshyaGraph(
        nodes: [_n('a'), _n('b')],
        edges: const [],
      );
      final next = mutator.addEdge(start, _e('e1', 'b', 'a'));
      expect(next.edges, hasLength(1));
      expect(() => mutator.addEdge(next, _e('e1', 'b', 'a')),
          throwsA(isA<ArgumentError>()));
    });

    test('addEdge rejects edges to/from unknown node ids', () {
      final start = LakshyaGraph(nodes: [_n('a')], edges: const []);
      expect(() => mutator.addEdge(start, _e('e1', 'a', 'ghost')),
          throwsA(isA<ArgumentError>()));
      expect(() => mutator.addEdge(start, _e('e1', 'ghost', 'a')),
          throwsA(isA<ArgumentError>()));
    });

    test('addEdge rejects cycles', () {
      final start = LakshyaGraph(
        nodes: [_n('root'), _n('a'), _n('b')],
        edges: [_e('e1', 'a', 'root'), _e('e2', 'b', 'a')],
      );
      // root <- a <- b. Adding root -> b would form root <- b <- a <- root.
      expect(() => mutator.addEdge(start, _e('e3', 'root', 'b')),
          throwsA(isA<StateError>()));
    });

    test('addEdge rejects self-loops', () {
      final start = LakshyaGraph(nodes: [_n('a')], edges: const []);
      expect(() => mutator.addEdge(start, _e('e1', 'a', 'a')),
          throwsA(isA<StateError>()));
    });

    test('removeEdge drops the edge by id', () {
      final start = LakshyaGraph(
        nodes: [_n('a'), _n('b')],
        edges: [_e('e1', 'b', 'a')],
      );
      final next = mutator.removeEdge(start, 'e1');
      expect(next.edges, isEmpty);
    });

    test('removeEdge throws when the id is not present', () {
      final start = LakshyaGraph(nodes: const [], edges: const []);
      expect(() => mutator.removeEdge(start, 'ghost'),
          throwsA(isA<ArgumentError>()));
    });
  });
}
