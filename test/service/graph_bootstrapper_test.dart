import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/repository/graph_repository.dart';
import 'package:lakshya/service/graph_bootstrapper.dart';
import 'package:lakshya/service/schema_validator.dart';

import '../support/builders.dart';

class _FakeRepo implements GraphRepository {
  LakshyaGraph? stored;
  bool throwOnLoad = false;

  @override
  Future<LakshyaGraph?> load() async {
    if (throwOnLoad) {
      throw const SchemaValidationException(
          errors: ['test validation error']);
    }
    return stored;
  }

  @override
  Future<void> save(LakshyaGraph graph) async => stored = graph;
}

void main() {
  final seed = LakshyaGraph(
    nodes: [buildNode('seed-root', title: 'Seed root')],
    edges: const [],
  );

  group('GraphBootstrapper', () {
    test('returns the loaded graph when repository has data', () async {
      final saved = LakshyaGraph(
        nodes: [buildNode('existing', title: 'Existing')],
        edges: const [],
      );
      final repo = _FakeRepo()..stored = saved;

      final result = await const GraphBootstrapper().loadOrBootstrap(
        repository: repo,
        seed: seed,
      );

      expect(result.graph.nodes.single.title, 'Existing');
      expect(result.recoveryNotice, isNull);
    });

    test('seeds and persists when repository is empty (first run)', () async {
      final repo = _FakeRepo(); // stored = null

      final result = await const GraphBootstrapper().loadOrBootstrap(
        repository: repo,
        seed: seed,
      );

      expect(result.graph.nodes.single.title, 'Seed root');
      expect(result.recoveryNotice, isNull);
      expect(repo.stored, isNotNull,
          reason: 'seed should be persisted on first run');
    });

    test('falls back to seed with a notice when load fails validation',
        () async {
      final repo = _FakeRepo()..throwOnLoad = true;

      final result = await const GraphBootstrapper().loadOrBootstrap(
        repository: repo,
        seed: seed,
      );

      expect(result.graph.nodes.single.title, 'Seed root');
      expect(result.recoveryNotice, isNotNull);
      expect(result.recoveryNotice, contains('failed validation'));
    });
  });
}
