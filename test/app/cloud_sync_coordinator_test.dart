import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/cloud_sync_coordinator.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/repository/graph_repository.dart';
import 'package:lakshya/service/cloud_sync_config.dart';
import 'package:lakshya/service/cloud_sync_provider.dart';
import 'package:lakshya/service/id_generator.dart';

import '../support/builders.dart';

class _FakeRepository implements GraphRepository {
  _FakeRepository({this.initial});

  LakshyaGraph? initial;
  LakshyaGraph? saved;

  @override
  Future<LakshyaGraph?> load() async => initial;

  @override
  Future<void> save(LakshyaGraph graph) async {
    saved = graph;
  }
}

void main() {
  test('startICloudSync loads remote graph when one exists', () async {
    final fallback = _FakeRepository();
    final remoteGraph = LakshyaGraph(
      nodes: [buildNode('root', title: 'Remote Root')],
      edges: const [],
    );
    final controller = GraphController(
      initial: LakshyaGraph(
        nodes: [buildNode('root', title: 'Local Root')],
        edges: const [],
      ),
      save: fallback.save,
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 25),
    );
    final cloud = _FakeRepository(initial: remoteGraph);
    final coordinator = CloudSyncCoordinator(
      controller: controller,
      fallbackRepository: fallback,
      config: const CloudSyncConfig(isWeb: true),
      connectICloud: (_) async => cloud,
    );

    await coordinator.startICloudSync();

    expect(coordinator.activeProviderId, CloudSyncProviderId.iCloud);
    expect(controller.graph, remoteGraph);
  });

  test('startICloudSync seeds the cloud when no remote graph exists', () async {
    final fallback = _FakeRepository();
    final localGraph = LakshyaGraph(
      nodes: [buildNode('root', title: 'Local Root')],
      edges: const [],
    );
    final controller = GraphController(
      initial: localGraph,
      save: fallback.save,
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 25),
    );
    final cloud = _FakeRepository();
    final coordinator = CloudSyncCoordinator(
      controller: controller,
      fallbackRepository: fallback,
      config: const CloudSyncConfig(isWeb: true),
      connectICloud: (_) async => cloud,
    );

    await coordinator.startICloudSync();

    expect(coordinator.activeProviderId, CloudSyncProviderId.iCloud);
    expect(cloud.saved, localGraph);
  });

  test('stopSync restores fallback persistence target', () async {
    final fallback = _FakeRepository();
    final controller = GraphController(
      initial: LakshyaGraph(
        nodes: [buildNode('root')],
        edges: const [],
      ),
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 25),
    );
    final cloud = _FakeRepository();
    final coordinator = CloudSyncCoordinator(
      controller: controller,
      fallbackRepository: fallback,
      config: const CloudSyncConfig(isWeb: true),
      connectICloud: (_) async => cloud,
    );

    await coordinator.startICloudSync();
    await coordinator.stopSync();
    controller.addChildNode(
      title: 'Task',
      parentId: 'root',
      status: NodeStatus.oneTime(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.activeProviderId, isNull);
    expect(fallback.saved, isNotNull);
  });
}
