import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/app/web_file_sync_coordinator.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/model/settings.dart';
import 'package:lakshya/repository/graph_repository.dart';
import 'package:lakshya/repository/web_graph_file_sync.dart';
import 'package:lakshya/service/cloud_sync_config.dart';
import 'package:lakshya/service/cloud_sync_registry.dart';
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
    expect(
      clipboardText,
      contains('"schemaVersion": $kCurrentSchemaVersion'),
    );
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

  testWidgets('shows JSON file import/export actions when desktop mode is enabled',
      (tester) async {
    final controller = GraphController(
      initial: const LakshyaGraph.empty(),
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    await tester.pumpWidget(MaterialApp(
      home: SettingsView(
        controller: controller,
        validator: validator,
        showDesktopFileActions: true,
      ),
    ));

    expect(find.text('Export to JSON file'), findsOneWidget);
    expect(find.text('Import from JSON file'), findsOneWidget);
  });

  testWidgets('notification defaults update document settings', (tester) async {
    final controller = GraphController(
      initial: const LakshyaGraph(
        nodes: [],
        edges: [],
        settings: Settings(
          defaultDeadlineLeadTimeHours: 23,
          notifyOnPeriodicReopenByDefault: false,
        ),
      ),
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    await tester.pumpWidget(MaterialApp(
      home: SettingsView(controller: controller, validator: validator),
    ));

    await tester.tap(find.text('Do not notify'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Always notify').last);
    await tester.pumpAndSettle();

    expect(
      controller.graph.settings,
      const Settings(
        defaultDeadlineLeadTimeHours: 23,
        notifyOnPeriodicReopenByDefault: true,
      ),
    );
  });

  testWidgets('web file sync section explains ongoing sync and cloud-backed files',
      (tester) async {
    final controller = GraphController(
      initial: const LakshyaGraph.empty(),
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );
    final coordinator = WebFileSyncCoordinator(
      fileSync: _FakeWebGraphFileSync(),
      controller: controller,
      validator: validator,
    );

    await tester.pumpWidget(MaterialApp(
      home: SettingsView(
        controller: controller,
        validator: validator,
        webFileSync: coordinator,
        fallbackRepository: _FakeGraphRepository(),
      ),
    ));

    expect(find.text('Sync to a file'), findsOneWidget);
    expect(find.text('Create file and sync…'), findsOneWidget);
    expect(find.text('Create cloud-backed file…'), findsOneWidget);
    expect(find.text('Open existing file and sync…'), findsOneWidget);
    expect(find.textContaining('cloud-synced folder'), findsOneWidget);
  });

  testWidgets('cloud-backed file action explains provider limitations',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GraphController(
      initial: const LakshyaGraph.empty(),
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );
    final coordinator = WebFileSyncCoordinator(
      fileSync: _FakeWebGraphFileSync(),
      controller: controller,
      validator: validator,
    );

    await tester.pumpWidget(MaterialApp(
      home: SettingsView(
        controller: controller,
        validator: validator,
        webFileSync: coordinator,
        fallbackRepository: _FakeGraphRepository(),
      ),
    ));

    final button = find.widgetWithText(
      OutlinedButton,
      'Create cloud-backed file…',
    );
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Pick a cloud-backed file'), findsOneWidget);
    expect(find.textContaining('does not log into Dropbox, Google Drive'), findsOneWidget);
    expect(find.text('Pick file'), findsOneWidget);
  });

  testWidgets('cloud provider registry renders the OneDrive setup card',
      (tester) async {
    final controller = GraphController(
      initial: const LakshyaGraph.empty(),
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );
    final registry = CloudSyncRegistry(
      config: const CloudSyncConfig(isWeb: true),
    );

    await tester.pumpWidget(MaterialApp(
      home: SettingsView(
        controller: controller,
        validator: validator,
        cloudSyncRegistry: registry,
      ),
    ));

    expect(find.text('Cloud provider sync'), findsOneWidget);
    expect(find.text('Microsoft OneDrive'), findsOneWidget);
    expect(find.text('Setup'), findsOneWidget);
  });
}

class _FakeWebGraphFileSync extends WebGraphFileSync {
  @override
  bool get isSupported => true;
}

class _FakeGraphRepository implements GraphRepository {
  @override
  Future<LakshyaGraph?> load() async => null;

  @override
  Future<void> save(LakshyaGraph graph) async {}
}
