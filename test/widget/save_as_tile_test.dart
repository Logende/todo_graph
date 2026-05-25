import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/todo_list_view.dart';

import '../support/builders.dart';

void main() {
  testWidgets('Save-as-tile adds a FilterPreset reflecting the live filter',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [buildNode('root')],
      edges: const [],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator('p'),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    await tester.pumpWidget(MaterialApp(
      home: TodoListView(
        controller: controller,
        title: 'All',
        filter: const Filter(),
        nowFactory: () => DateTime.utc(2026, 5, 24, 12),
      ),
    ));

    // Open the filter drawer via the app-bar action.
    await tester.tap(find.byTooltip('Filter & save'));
    await tester.pumpAndSettle();

    // Refine the filter from inside the drawer.
    await tester.scrollUntilVisible(
      find.text('Only ongoing'),
      200,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Only ongoing'));
    await tester.pumpAndSettle();

    // Trigger "Save as tile".
    await tester.tap(find.widgetWithText(FilledButton, 'Save as tile'));
    await tester.pumpAndSettle();

    // Confirm the dialog. There are two text fields on screen (the drawer's
    // "Free text" and the dialog's "Tile title") — pick the one inside the
    // AlertDialog by descending from it.
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'Today');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(controller.graph.filterPresets, hasLength(1));
    final saved = controller.graph.filterPresets.single;
    expect(saved.title, equals('Today'));
    expect(saved.filter.onlyOngoing, isTrue);
  });
}
