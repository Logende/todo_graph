import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/id_generator.dart';

void main() {
  group('GraphController', () {
    test('exposes the initial graph', () {
      const initial = LakshyaGraph.empty();
      final controller = GraphController(
        initial: initial,
        save: (_) async {},
        idGenerator: SequentialIdGenerator(),
        clock: () => DateTime.utc(2026, 5, 24),
      );
      expect(controller.graph, equals(initial));
    });

    test('addNode appends to the graph, notifies, and triggers save', () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'root',
            title: 'All goals achieved',
            status: NodeStatus.alwaysOnBackground,
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      LakshyaGraph? saved;
      final controller = GraphController(
        initial: initial,
        save: (g) async => saved = g,
        idGenerator: SequentialIdGenerator('id'),
        clock: () => DateTime.utc(2026, 5, 24, 12),
      );
      var notifyCount = 0;
      controller.addListener(() => notifyCount += 1);

      controller.addChildNode(
        title: 'Health',
        parentId: 'root',
        status: NodeStatus.alwaysOnBackground,
      );

      expect(controller.graph.nodes.map((n) => n.id),
          equals(['root', 'id-1']));
      expect(controller.graph.edges, hasLength(1));
      expect(controller.graph.edges.single.childId, 'id-1');
      expect(controller.graph.edges.single.parentId, 'root');
      expect(notifyCount, 1);
      // Save is fire-and-forget; pump the microtask queue.
      await Future<void>.delayed(Duration.zero);
      expect(saved, isNotNull);
      expect(saved!.nodes.map((n) => n.id), equals(['root', 'id-1']));
    });

    test('markCompleted updates the status and notifies', () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'task',
            title: 'Write paper',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      final completedAt = DateTime.utc(2026, 5, 24, 13);
      final controller = GraphController(
        initial: initial,
        save: (_) async {},
        idGenerator: SequentialIdGenerator(),
        clock: () => completedAt,
      );

      controller.markCompleted('task');

      final updated =
          controller.graph.nodes.single.status.completion as OneTimeCompletion;
      expect(updated.completedAt, equals(completedAt));
    });

    test('replaceWith swaps the entire graph (used by JSON import)', () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'old',
            title: 'Old',
            status: NodeStatus.alwaysOnBackground,
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      const incoming = LakshyaGraph.empty();
      LakshyaGraph? saved;
      final controller = GraphController(
        initial: initial,
        save: (g) async => saved = g,
        idGenerator: SequentialIdGenerator(),
        clock: () => DateTime.utc(2026, 5, 24),
      );

      controller.replaceWith(incoming);

      expect(controller.graph, equals(incoming));
      await Future<void>.delayed(Duration.zero);
      expect(saved, equals(incoming));
    });
  });
}
