import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/impact.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/todo_list_view.dart';

import '../support/builders.dart';

void main() {
  testWidgets(
      'quick-add "Background goal" produces a node with no completion',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [buildNode('root')],
      edges: const [],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator('n'),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );

    await tester.pumpWidget(MaterialApp(
      home: TodoListView(
        controller: controller,
        title: 'All',
        filter: const Filter(),
        nowFactory: () => DateTime.utc(2026, 5, 24, 12),
      ),
    ));

    // Open the quick-add dialog for the root node via its "+" button.
    await tester.tap(find.byTooltip('Add child'));
    await tester.pumpAndSettle();

    // Pick "Background goal" then enter title and submit.
    await tester.tap(find.text('Background goal'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Health');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    final added = controller.graph.nodes.firstWhere((n) => n.title == 'Health');
    expect(added.status.completion, isNull,
        reason: 'background goal must have no completion concept');

    // The leading widget for a background goal is the flag icon, not a
    // checkbox.
    final rowFinder = find.ancestor(
      of: find.text('Health'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: rowFinder, matching: find.byIcon(Icons.flag_outlined)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rowFinder, matching: find.byType(Checkbox)),
      findsNothing,
    );
  });

  testWidgets('quick-add can mark a child as helpful', (tester) async {
    final graph = LakshyaGraph(
      nodes: [buildNode('root')],
      edges: const [],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator('n'),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );

    await tester.pumpWidget(MaterialApp(
      home: TodoListView(
        controller: controller,
        title: 'All',
        filter: const Filter(),
        nowFactory: () => DateTime.utc(2026, 5, 24, 12),
      ),
    ));

    await tester.tap(find.byTooltip('Add child'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Helpful'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Reference note');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    final added = controller.graph.nodes.firstWhere(
      (n) => n.title == 'Reference note',
    );
    final edge = controller.graph.edges.firstWhere((e) => e.childId == added.id);
    expect(edge.contribution, Contribution.helpful);
  });

  testWidgets('quick-add can set impact and deadline', (tester) async {
    final graph = LakshyaGraph(
      nodes: [buildNode('root')],
      edges: const [],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator('n'),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );

    await tester.pumpWidget(MaterialApp(
      home: TodoListView(
        controller: controller,
        title: 'All',
        filter: const Filter(),
        nowFactory: () => DateTime.utc(2026, 5, 24, 12),
      ),
    ));

    await tester.tap(find.byTooltip('Add child'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Prepare brief');
    await tester.tap(find.byType(DropdownButtonFormField<Impact?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('High').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pick deadline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    final added = controller.graph.nodes.firstWhere(
      (n) => n.title == 'Prepare brief',
    );
    expect(added.impact, Impact.high);
    expect(added.deadline, DateTime(2026, 5, 30));
  });

  testWidgets('quick-add "Every 3 days" produces a periodic-3 completion',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [buildNode('root')],
      edges: const [],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator('n'),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );

    await tester.pumpWidget(MaterialApp(
      home: TodoListView(
        controller: controller,
        title: 'All',
        filter: const Filter(),
        nowFactory: () => DateTime.utc(2026, 5, 24, 12),
      ),
    ));

    await tester.tap(find.byTooltip('Add child'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every 3 days'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Push day');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    final added = controller.graph.nodes.firstWhere(
      (n) => n.title == 'Push day',
    );
    expect(added.status.completion, isA<PeriodicCompletion>());
    final periodic = added.status.completion as PeriodicCompletion;
    expect(periodic.intervalDaysSinceLastCompletion, 3);
  });
}
