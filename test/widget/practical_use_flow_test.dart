import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/view/dashboard_view.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/settings.dart';
import 'package:lakshya/service/id_generator.dart';

import '../support/builders.dart';

void main() {
  testWidgets(
      'practical flow: add task, save tile, rename it, and see dashboard update',
      (tester) async {
    void popCurrentRoute(Finder anchor) {
      Navigator.of(tester.element(anchor)).pop();
    }

    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'All goals achieved'),
        buildNode('work', title: 'Work'),
      ],
      edges: [
        buildEdge('e1', from: 'work', to: 'root'),
      ],
      settings: const Settings(rootNodeId: 'root'),
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator('id'),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );

    await tester.pumpWidget(MaterialApp(
      home: DashboardView(controller: controller),
    ));

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Write abstract',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pumpAndSettle();

    expect(
      controller.graph.nodes.any((n) => n.title == 'Write abstract'),
      isTrue,
    );
    expect(
      controller.graph.nodes
          .firstWhere((n) => n.title == 'Write abstract')
          .status
          .completion,
      isA<OneTimeCompletion>(),
    );

    expect(find.text('Write abstract'), findsOneWidget);

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save as tile'));
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'Paper tasks');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Paper tasks'), findsNothing,
        reason: 'still inside the list view after saving');

    popCurrentRoute(find.text('Write abstract'));
    await tester.pumpAndSettle();
    popCurrentRoute(find.text('Write abstract'));
    await tester.pumpAndSettle();

    expect(find.text('Paper tasks'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage saved tiles'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rename'));
    await tester.pumpAndSettle();
    final renameField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(renameField, 'Writing');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    popCurrentRoute(find.text('Manage saved tiles'));
    await tester.pumpAndSettle();
    popCurrentRoute(find.text('Manage saved tiles'));
    await tester.pumpAndSettle();

    expect(find.text('Writing'), findsOneWidget);
    expect(find.text('Paper tasks'), findsNothing);
  });
}
