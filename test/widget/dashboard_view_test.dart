import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/filter_preset.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/dashboard_view.dart';
import 'package:lakshya/view/todo_list_view.dart';

void main() {
  testWidgets('renders built-in tiles plus user-defined filter preset tiles',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        Node(
          id: 'root',
          title: 'All goals achieved',
          status: const AlwaysOnStatus(),
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

    await tester.pumpWidget(MaterialApp(
      home: DashboardView(controller: controller),
    ));

    expect(find.text('All ongoing'), findsOneWidget);
    expect(find.text('All goals'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('tapping a tile navigates to TodoListView with that filter',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        Node(
          id: 'root',
          title: 'All goals achieved',
          status: const AlwaysOnStatus(),
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

    await tester.pumpWidget(MaterialApp(
      home: DashboardView(controller: controller),
    ));

    await tester.tap(find.text('All goals'));
    await tester.pumpAndSettle();

    expect(find.byType(TodoListView), findsOneWidget);
    expect(find.text('All goals achieved'), findsOneWidget,
        reason: 'the empty filter surfaces the root node');
  });
}
