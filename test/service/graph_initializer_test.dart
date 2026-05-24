import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/graph_initializer.dart';
import 'package:lakshya/service/id_generator.dart';

void main() {
  group('GraphInitializer.emptyGraph', () {
    test('creates a single root node titled "All goals achieved"', () {
      final clock = DateTime.utc(2026, 5, 24, 12);
      final ids = SequentialIdGenerator('root');
      final initialiser =
          GraphInitializer(idGenerator: ids, clock: () => clock);

      final graph = initialiser.emptyGraph();

      expect(graph.nodes, hasLength(1));
      expect(graph.edges, isEmpty);
      expect(graph.nodes.single.title, equals('All goals achieved'));
      expect(graph.nodes.single.status, isA<AlwaysOnStatus>());
      expect(graph.nodes.single.createdAt, equals(clock));
      expect(graph.settings, isNotNull);
      expect(graph.settings!.rootNodeId, equals(graph.nodes.single.id));
    });

    test('uses the id generator for the root node id', () {
      final ids = SequentialIdGenerator('prefix');
      final initialiser = GraphInitializer(
        idGenerator: ids,
        clock: () => DateTime.utc(2026, 5, 24),
      );

      final graph = initialiser.emptyGraph();

      expect(graph.nodes.single.id, equals('prefix-1'));
    });
  });
}
