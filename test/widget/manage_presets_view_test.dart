import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/filter_preset.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/manage_presets_view.dart';

import '../support/builders.dart';

GraphController _controllerWithPresets(List<FilterPreset> presets) {
  return GraphController(
    initial: LakshyaGraph(
      nodes: [buildNode('root')],
      edges: const [],
      filterPresets: presets,
    ),
    save: (_) async {},
    idGenerator: SequentialIdGenerator(),
    clock: () => DateTime.utc(2026, 5, 24),
  );
}

void main() {
  testWidgets('empty state explains how to create tiles', (tester) async {
    final controller = _controllerWithPresets(const []);
    await tester.pumpWidget(MaterialApp(
      home: ManagePresetsView(controller: controller),
    ));
    expect(find.textContaining('No saved tiles yet'), findsOneWidget);
  });

  testWidgets('rename updates the preset title', (tester) async {
    final controller = _controllerWithPresets(const [
      FilterPreset(id: 'p1', title: 'Old name', filter: Filter()),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: ManagePresetsView(controller: controller),
    ));

    await tester.tap(find.byTooltip('Rename'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'Renamed');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(controller.graph.filterPresets.single.title, equals('Renamed'));
  });

  testWidgets('delete removes the preset after confirmation', (tester) async {
    final controller = _controllerWithPresets(const [
      FilterPreset(id: 'p1', title: 'Doomed', filter: Filter()),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: ManagePresetsView(controller: controller),
    ));

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(controller.graph.filterPresets, isEmpty);
  });
}
