import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/edge.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/filter_preset.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/model/settings.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/dashboard_view.dart';
import 'package:lakshya/view/hybrid_hierarchy_view.dart';

void main() {
  testWidgets('renders built-in tiles plus user-defined filter preset tiles', (
    tester,
  ) async {
    final graph = LakshyaGraph(
      nodes: [
        Node(
          id: 'root',
          title: 'All goals achieved',
          status: NodeStatus.alwaysOnBackground,
          createdAt: DateTime.utc(2026, 5, 24),
        ),
      ],
      edges: const [],
      filterPresets: const [
        FilterPreset(
          id: 'fp-1',
          title: 'Work',
          filter: Filter(onlyOngoing: true),
        ),
      ],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardView(controller: controller)),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('auto-generates one tile per direct child of the root goal', (
    tester,
  ) async {
    final graph = LakshyaGraph(
      nodes: [
        Node(
          id: 'root',
          title: 'All goals achieved',
          status: NodeStatus.alwaysOnBackground,
          createdAt: DateTime.utc(2026, 5, 24),
        ),
        Node(
          id: 'health',
          title: 'Health',
          status: NodeStatus.alwaysOnBackground,
          createdAt: DateTime.utc(2026, 5, 24),
        ),
        Node(
          id: 'work',
          title: 'Work',
          status: NodeStatus.alwaysOnBackground,
          createdAt: DateTime.utc(2026, 5, 24),
        ),
        Node(
          id: 'leaf',
          title: 'Leaf under health',
          status: NodeStatus.oneTime(),
          createdAt: DateTime.utc(2026, 5, 24),
        ),
      ],
      edges: const [
        Edge(
          id: 'e1',
          childId: 'health',
          parentId: 'root',
          contribution: Contribution.mandatory,
        ),
        Edge(
          id: 'e2',
          childId: 'work',
          parentId: 'root',
          contribution: Contribution.mandatory,
        ),
        Edge(
          id: 'e3',
          childId: 'leaf',
          parentId: 'health',
          contribution: Contribution.mandatory,
        ),
      ],
      settings: const Settings(rootNodeId: 'root'),
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardView(controller: controller)),
    );

    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(
      find.text('Leaf under health'),
      findsNothing,
      reason: 'only direct children of root get an auto-tile',
    );
  });

  testWidgets('tapping All opens the shared explorer with that filter', (
    tester,
  ) async {
    final graph = LakshyaGraph(
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
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardView(controller: controller)),
    );

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.byType(HybridHierarchyView), findsOneWidget);
    expect(
      find.text('All goals achieved'),
      findsOneWidget,
      reason: 'the empty filter surfaces the root node',
    );
  });

  testWidgets('saved graph tile opens explorer with graph mode', (
    tester,
  ) async {
    final graph = LakshyaGraph(
      nodes: [
        Node(
          id: 'root',
          title: 'All goals achieved',
          status: NodeStatus.alwaysOnBackground,
          createdAt: DateTime.utc(2026, 5, 24),
        ),
      ],
      edges: const [],
      filterPresets: const [
        FilterPreset(
          id: 'graph-tile',
          title: 'Graph tile',
          filter: Filter(),
          viewSettings: ExplorerViewSettings(
            displayMode: ExplorerDisplayMode.graph,
          ),
        ),
      ],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardView(controller: controller)),
    );

    expect(find.text('Graph tile'), findsOneWidget);

    await tester.tap(find.text('Graph tile'));
    await tester.pumpAndSettle();

    expect(find.byType(HybridHierarchyView), findsOneWidget);
    expect(find.text('Leaves'), findsOneWidget);
  });

  testWidgets('All tile remembers its display mode across reopens', (
    tester,
  ) async {
    final graph = LakshyaGraph(
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
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardView(controller: controller)),
    );

    // Open "All" (defaults to the tree list) and switch it to the graph.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show graph'), findsOneWidget);
    await tester.tap(find.byTooltip('Show graph'));
    await tester.pumpAndSettle();

    expect(
      controller.graph.settings?.tileViewSettings['tile:all']?.displayMode,
      ExplorerDisplayMode.graph,
      reason: 'switching the mode persists it for the tile',
    );

    // Back to the dashboard, then reopen the same tile.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // It reopens in graph mode, so the toggle now offers the tree list.
    expect(find.byTooltip('Show tree list'), findsOneWidget);
    expect(find.text('Leaves'), findsOneWidget);
  });
}
