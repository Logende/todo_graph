import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/impact.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/node_detail_view.dart';

import '../support/builders.dart';

GraphController _controllerWith(LakshyaGraph graph) => GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator('id'),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );

void main() {
  Future<void> pumpAndOpenEditor(
      WidgetTester tester, GraphController c, String nodeId) async {
    await tester.pumpWidget(MaterialApp(
      home: NodeDetailView(controller: c, nodeId: nodeId),
    ));
    await tester.tap(find.byTooltip('Edit node'));
    await tester.pumpAndSettle();
    expect(find.text('Edit node'), findsOneWidget,
        reason: 'editor dialog should be open');
  }

  testWidgets('editing title only preserves impact and completion',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('a',
            title: 'Old title',
            status: NodeStatus.oneTime(),
            impact: Impact.high),
      ],
      edges: const [],
    );
    final c = _controllerWith(graph);

    await pumpAndOpenEditor(tester, c, 'a');

    // Find the title field by its label and change it.
    final titleFields = find.byType(TextFormField);
    await tester.enterText(titleFields.first, 'New title');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final updated = c.graph.nodes.single;
    expect(updated.title, 'New title');
    expect(updated.impact, Impact.high, reason: 'impact preserved');
    expect(updated.status.completion, isA<OneTimeCompletion>(),
        reason: 'completion type preserved');
  });

  testWidgets('editor dialog opens with current values populated',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('a',
            title: 'My task',
            status: NodeStatus.periodic(
              intervalDaysSinceLastCompletion: 7,
            ),
            impact: Impact.critical,
            deadline: DateTime.utc(2026, 6, 15)),
      ],
      edges: const [],
    );
    final c = _controllerWith(graph);

    await pumpAndOpenEditor(tester, c, 'a');

    // The title field should contain the current title.
    expect(find.text('My task'), findsWidgets);
    // Impact dropdown should show "Critical".
    expect(find.text('Critical'), findsWidgets);
    // The deadline line should be visible (may appear in the detail screen
    // behind the dialog as well, so at least one is enough).
    expect(find.textContaining('2026-06-15'), findsWidgets);
    // Periodic interval should show 7.
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('saving without changes produces an equal node', (tester) async {
    final graph = LakshyaGraph(
      nodes: [buildNode('a', title: 'Unchanged', status: NodeStatus.oneTime())],
      edges: const [],
    );
    final c = _controllerWith(graph);

    await pumpAndOpenEditor(tester, c, 'a');

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final updated = c.graph.nodes.single;
    expect(updated.title, 'Unchanged');
    expect(updated.status.completion, isA<OneTimeCompletion>());
  });

  testWidgets('cancel does not apply changes', (tester) async {
    final graph = LakshyaGraph(
      nodes: [buildNode('a', title: 'Original', status: NodeStatus.oneTime())],
      edges: const [],
    );
    final c = _controllerWith(graph);

    await pumpAndOpenEditor(tester, c, 'a');

    // Change title then cancel.
    final titleFields = find.byType(TextFormField);
    await tester.enterText(titleFields.first, 'Changed');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(c.graph.nodes.single.title, 'Original',
        reason: 'cancel should not persist changes');
  });
}
