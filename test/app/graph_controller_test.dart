import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/node_relationship.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/model/settings.dart';
import 'package:lakshya/service/id_generator.dart';

import '../support/builders.dart';

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

    test('markIncomplete reopens a completed one-time task', () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'task',
            title: 'Write paper',
            status: NodeStatus.oneTime(
              completedAt: DateTime.utc(2026, 5, 24, 13),
            ),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      final controller = GraphController(
        initial: initial,
        save: (_) async {},
        idGenerator: SequentialIdGenerator(),
        clock: () => DateTime.utc(2026, 5, 24, 14),
      );

      controller.markIncomplete('task');

      final updated =
          controller.graph.nodes.single.status.completion as OneTimeCompletion;
      expect(updated.completedAt, isNull);
    });

    test(
        'markCompleted cascades through alternativeTo relationships',
        () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'paper-a',
            title: 'Paper A',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: 'paper-b',
            title: 'Paper B',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: 'paper-c',
            title: 'Paper C',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
        relationships: const [
          NodeRelationship(
            id: 'r1',
            fromNodeId: 'paper-a',
            toNodeId: 'paper-b',
            kind: RelationshipKind.alternativeTo,
          ),
          NodeRelationship(
            id: 'r2',
            fromNodeId: 'paper-b',
            toNodeId: 'paper-c',
            kind: RelationshipKind.alternativeTo,
          ),
        ],
      );
      final completedAt = DateTime.utc(2026, 5, 24, 15);
      final controller = GraphController(
        initial: initial,
        save: (_) async {},
        idGenerator: SequentialIdGenerator(),
        clock: () => completedAt,
      );

      controller.markCompleted('paper-a');

      // The transitive cascade closes B (alternative of A) and C
      // (alternative of B), each in a single user action.
      for (final id in ['paper-a', 'paper-b', 'paper-c']) {
        final completion = controller.graph.nodes
            .firstWhere((n) => n.id == id)
            .status
            .completion as OneTimeCompletion;
        expect(completion.completedAt, equals(completedAt),
            reason: '$id should have been cascaded closed');
      }
    });

    test(
        'markCompleted on a background goal is a no-op (and does not cascade)',
        () async {
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
      final controller = GraphController(
        initial: initial,
        save: (_) async {},
        idGenerator: SequentialIdGenerator(),
        clock: () => DateTime.utc(2026, 5, 24, 12),
      );

      controller.markCompleted('root');

      expect(controller.graph, equals(initial));
    });

    test('addRelationship and removeRelationship update the graph', () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'a',
            title: 'A',
            status: NodeStatus.alwaysOnBackground,
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: 'b',
            title: 'B',
            status: NodeStatus.alwaysOnBackground,
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      final controller = GraphController(
        initial: initial,
        save: (_) async {},
        idGenerator: SequentialIdGenerator('id'),
        clock: () => DateTime.utc(2026, 5, 24),
      );

      controller.addRelationship(
        fromNodeId: 'a',
        toNodeId: 'b',
        kind: RelationshipKind.moreImportantThan,
      );
      expect(controller.graph.relationships, hasLength(1));
      final added = controller.graph.relationships.single;
      expect(added.kind, equals(RelationshipKind.moreImportantThan));

      controller.removeRelationship(added.id);
      expect(controller.graph.relationships, isEmpty);
    });

    test(
        'setMoreImportantThan adds a moreImportantThan relationship between '
        'two siblings', () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'a',
            title: 'A',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: 'b',
            title: 'B',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      final controller = GraphController(
        initial: initial,
        save: (_) async {},
        idGenerator: SequentialIdGenerator('rel'),
        clock: () => DateTime.utc(2026, 5, 24),
      );

      controller.setMoreImportantThan(higherId: 'a', lowerId: 'b');

      expect(controller.graph.relationships, hasLength(1));
      final added = controller.graph.relationships.single;
      expect(added.kind, equals(RelationshipKind.moreImportantThan));
      expect(added.fromNodeId, equals('a'));
      expect(added.toNodeId, equals('b'));
    });

    test(
        'setMoreImportantThan removes the opposite direction when flipping '
        'the order', () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'a',
            title: 'A',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: 'b',
            title: 'B',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
        relationships: const [
          NodeRelationship(
            id: 'old',
            fromNodeId: 'b',
            toNodeId: 'a',
            kind: RelationshipKind.moreImportantThan,
          ),
        ],
      );
      final controller = GraphController(
        initial: initial,
        save: (_) async {},
        idGenerator: SequentialIdGenerator('rel'),
        clock: () => DateTime.utc(2026, 5, 24),
      );

      controller.setMoreImportantThan(higherId: 'a', lowerId: 'b');

      expect(controller.graph.relationships, hasLength(1));
      final after = controller.graph.relationships.single;
      expect(after.fromNodeId, equals('a'));
      expect(after.toNodeId, equals('b'));
    });

    test(
        'setMoreImportantThan is a no-op when the relationship already '
        'exists in the requested direction', () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'a',
            title: 'A',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: 'b',
            title: 'B',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
        relationships: const [
          NodeRelationship(
            id: 'r-keep',
            fromNodeId: 'a',
            toNodeId: 'b',
            kind: RelationshipKind.moreImportantThan,
          ),
        ],
      );
      final controller = GraphController(
        initial: initial,
        save: (_) async {},
        idGenerator: SequentialIdGenerator('rel'),
        clock: () => DateTime.utc(2026, 5, 24),
      );

      controller.setMoreImportantThan(higherId: 'a', lowerId: 'b');

      expect(controller.graph.relationships, hasLength(1));
      expect(controller.graph.relationships.single.id, equals('r-keep'));
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

    test('setCollapsedNodeIds persists hierarchical tree state in settings',
        () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'root',
            title: 'Root',
            status: NodeStatus.alwaysOnBackground,
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      final controller = GraphController(
        initial: initial,
        save: (_) async {},
        idGenerator: SequentialIdGenerator(),
        clock: () => DateTime.utc(2026, 5, 24),
      );

      controller.setCollapsedNodeIds(['root']);

      expect(
        controller.graph.settings,
        const Settings(collapsedNodeIds: ['root']),
      );
    });

    test('moveNodeToParent reparents an existing edge', () async {
      final initial = LakshyaGraph(
        nodes: [
          Node(
            id: 'root',
            title: 'Root',
            status: NodeStatus.alwaysOnBackground,
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: 'cooperations',
            title: 'Cooperations',
            status: NodeStatus.alwaysOnBackground,
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: 'department',
            title: 'XY Department',
            status: NodeStatus.alwaysOnBackground,
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: 'talk',
            title: 'Talk with Peter',
            status: NodeStatus.oneTime(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      final controller = GraphController(
        initial: initial.copyWith(
          edges: [
            buildEdge('e1', from: 'cooperations', to: 'root'),
            buildEdge('e2', from: 'department', to: 'cooperations'),
            buildEdge('e3', from: 'talk', to: 'cooperations'),
          ],
        ),
        save: (_) async {},
        idGenerator: SequentialIdGenerator(),
        clock: () => DateTime.utc(2026, 5, 24),
      );

      controller.moveNodeToParent(
        childId: 'talk',
        fromParentId: 'cooperations',
        toParentId: 'department',
      );

      final moved = controller.graph.edges.firstWhere((e) => e.id == 'e3');
      expect(moved.parentId, 'department');
    });
  });
}
