import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/graph_io.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/service/schema_validator.dart';
import 'package:lakshya/view/settings_view.dart';

void main() {
  late SchemaValidator validator;

  setUpAll(() {
    final schemaText =
        File('schema/lakshya.schema.json').readAsStringSync();
    validator = SchemaValidator.fromString(schemaText);
  });

  testWidgets('Export to JSON copies a schema-valid document to the clipboard',
      (tester) async {
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

    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(MaterialApp(
      home: SettingsView(controller: controller, validator: validator),
    ));

    await tester.tap(find.text('Export to JSON'));
    await tester.pump();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"schemaVersion": 1'));
    // The exported text must round-trip back through Import.
    final imported =
        GraphIo(validator: validator).importFromJson(clipboardText!);
    expect(imported, equals(graph));
  });

  testWidgets('Import rejects clipboard contents that fail schema validation',
      (tester) async {
    final controller = GraphController(
      initial: const LakshyaGraph.empty(),
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {'text': '{"schemaVersion": 1}'};
      }
      return null;
    });

    await tester.pumpWidget(MaterialApp(
      home: SettingsView(controller: controller, validator: validator),
    ));

    await tester.tap(find.text('Import from JSON'));
    await tester.pumpAndSettle();

    expect(find.text('Import rejected: invalid schema'), findsOneWidget);
    // Graph unchanged.
    expect(controller.graph, equals(const LakshyaGraph.empty()));
  });
}
