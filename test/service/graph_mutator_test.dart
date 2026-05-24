import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/graph_mutator.dart';

import '../support/builders.dart';

void main() {
  group('GraphMutator', () {
    const mutator = GraphMutator();

    test('addNode appends without touching edges', () {
      final start = LakshyaGraph(nodes: [buildNode('a')], edges: const []);
      final next = mutator.addNode(start, buildNode('b'));
      expect(next.nodes.map((n) => n.id), equals(['a', 'b']));
      expect(next.edges, isEmpty);
    });

    test('addNode rejects duplicate ids', () {
      final start = LakshyaGraph(nodes: [buildNode('a')], edges: const []);
      expect(() => mutator.addNode(start, buildNode('a')),
          throwsA(isA<ArgumentError>()));
    });

    test('updateNode replaces by id and keeps node order', () {
      final start = LakshyaGraph(
        nodes: [buildNode('a'), buildNode('b'), buildNode('c')],
        edges: const [],
      );
      final updated = Node(
        id: 'b',
        title: 'B-updated',
        status: NodeStatus.oneTime(),
        createdAt: DateTime.utc(2026, 5, 24),
      );
      final next = mutator.updateNode(start, updated);
      expect(next.nodes.map((n) => n.id), equals(['a', 'b', 'c']));
      expect(next.nodes[1].title, equals('B-updated'));
    });

    test('updateNode throws when the id is not present', () {
      final start = LakshyaGraph(nodes: [buildNode('a')], edges: const []);
      expect(() => mutator.updateNode(start, buildNode('ghost')),
          throwsA(isA<ArgumentError>()));
    });

    test('deleteNode removes the node and all incident edges', () {
      final start = LakshyaGraph(
        nodes: [buildNode('a'), buildNode('b'), buildNode('c')],
        edges: [buildEdge('e1', from: 'b', to: 'a'), buildEdge('e2', from: 'c', to: 'b')],
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
        nodes: [buildNode('a'), buildNode('b')],
        edges: const [],
      );
      final next = mutator.addEdge(start, buildEdge('e1', from: 'b', to: 'a'));
      expect(next.edges, hasLength(1));
      expect(() => mutator.addEdge(next, buildEdge('e1', from: 'b', to: 'a')),
          throwsA(isA<ArgumentError>()));
    });

    test('addEdge rejects edges to/from unknown node ids', () {
      final start = LakshyaGraph(nodes: [buildNode('a')], edges: const []);
      expect(() => mutator.addEdge(start, buildEdge('e1', from: 'a', to: 'ghost')),
          throwsA(isA<ArgumentError>()));
      expect(() => mutator.addEdge(start, buildEdge('e1', from: 'ghost', to: 'a')),
          throwsA(isA<ArgumentError>()));
    });

    test('addEdge rejects cycles', () {
      final start = LakshyaGraph(
        nodes: [buildNode('root'), buildNode('a'), buildNode('b')],
        edges: [buildEdge('e1', from: 'a', to: 'root'), buildEdge('e2', from: 'b', to: 'a')],
      );
      // root <- a <- b. Adding root -> b would form root <- b <- a <- root.
      expect(() => mutator.addEdge(start, buildEdge('e3', from: 'root', to: 'b')),
          throwsA(isA<StateError>()));
    });

    test('addEdge rejects self-loops', () {
      final start = LakshyaGraph(nodes: [buildNode('a')], edges: const []);
      expect(() => mutator.addEdge(start, buildEdge('e1', from: 'a', to: 'a')),
          throwsA(isA<StateError>()));
    });

    test('removeEdge drops the edge by id', () {
      final start = LakshyaGraph(
        nodes: [buildNode('a'), buildNode('b')],
        edges: [buildEdge('e1', from: 'b', to: 'a')],
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
