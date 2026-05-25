import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/app/web_file_sync_coordinator.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/repository/graph_repository.dart';
import 'package:lakshya/repository/web_graph_file_sync.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/service/schema_validator.dart';

import '../support/builders.dart';

class _FakeRepository implements GraphRepository {
  LakshyaGraph? stored;

  @override
  Future<LakshyaGraph?> load() async => stored;

  @override
  Future<void> save(LakshyaGraph graph) async => stored = graph;
}

void main() {
  late GraphController controller;
  late _FakeRepository fallback;
  late SchemaValidator validator;
  late WebFileSyncCoordinator coordinator;

  setUp(() {
    fallback = _FakeRepository();
    final graph = LakshyaGraph(
      nodes: [buildNode('root')],
      edges: const [],
    );
    controller = GraphController(
      initial: graph,
      save: fallback.save,
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );
    // The stub WebGraphFileSync always reports isSupported=false and
    // returns null from all methods, which is fine for testing the
    // coordinator's integration logic (it gracefully handles all null returns).
    validator = SchemaValidator.fromString('{"type": "object"}');
    coordinator = WebFileSyncCoordinator(
      fileSync: const WebGraphFileSync(),
      controller: controller,
      validator: validator,
    );
  });

  test('isSupported reports the underlying fileSync capability', () {
    // The stub is always false (non-web platform).
    expect(coordinator.isSupported, isFalse);
  });

  test('startSyncToNewFile returns false when not supported', () async {
    final result = await coordinator.startSyncToNewFile(
      suggestedName: 'test.json',
    );
    expect(result, isFalse);
    expect(coordinator.isActive, isFalse);
  });

  test('startSyncFromExistingFile returns false when not supported', () async {
    final result = await coordinator.startSyncFromExistingFile();
    expect(result, isFalse);
    expect(coordinator.isActive, isFalse);
  });

  test('stopSync reverts save target to fallback repository', () async {
    // Even though file sync isn't active, calling stopSync should
    // rebind the controller's save callback to the fallback.
    await coordinator.stopSync(fallback: fallback);
    expect(coordinator.isActive, isFalse);

    // Verify save goes through fallback by modifying the graph.
    controller.addChildNode(
      title: 'New',
      parentId: 'root',
      status: NodeStatus.alwaysOnBackground,
    );
    await Future<void>.delayed(Duration.zero);
    expect(fallback.stored, isNotNull);
    expect(fallback.stored!.nodes.length, greaterThan(1));
  });
}
