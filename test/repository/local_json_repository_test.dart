import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/generated/lakshya_graph.dart';
import 'package:lakshya/repository/graph_repository.dart';
import 'package:lakshya/repository/local_json_repository.dart';

void main() {
  late Directory tempDir;
  late File graphFile;
  late LocalJsonRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lakshya_repo_test_');
    graphFile = File('${tempDir.path}/graph.json');
    repository = LocalJsonRepository(file: graphFile);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalJsonRepository', () {
    test('implements GraphRepository', () {
      expect(repository, isA<GraphRepository>());
    });

    test('load returns null when the file does not exist', () async {
      expect(await graphFile.exists(), isFalse);

      final loaded = await repository.load();

      expect(loaded, isNull);
    });

    test('save then load returns an equivalent graph', () async {
      final original = LakshyaGraph(
        schemaVersion: 1,
        nodes: [
          NodeElement(
            id: '11111111-1111-1111-1111-111111111111',
            title: 'Health',
            status: Status(type: TypeElement.ALWAYS_ON),
            createdAt: DateTime.utc(2026, 5, 24, 10),
          ),
          NodeElement(
            id: '22222222-2222-2222-2222-222222222222',
            title: 'Push day',
            status: Status(
              type: TypeElement.PERIODIC,
              intervalDaysSinceLastCompletion: 3,
              lastCompletedAt: DateTime.utc(2026, 5, 22, 18),
            ),
            createdAt: DateTime.utc(2026, 5, 24, 10),
          ),
        ],
        edges: [
          EdgeElement(
            id: '33333333-3333-3333-3333-333333333333',
            childId: '22222222-2222-2222-2222-222222222222',
            parentId: '11111111-1111-1111-1111-111111111111',
            contribution: EdgeContribution.MANDATORY,
          ),
        ],
      );

      await repository.save(original);
      final loaded = await repository.load();

      expect(loaded, isNotNull);
      expect(loaded!.schemaVersion, equals(1));
      expect(loaded.nodes, hasLength(2));
      expect(loaded.nodes[0].title, equals('Health'));
      expect(loaded.nodes[1].status.type, equals(TypeElement.PERIODIC));
      expect(
        loaded.nodes[1].status.intervalDaysSinceLastCompletion,
        equals(3),
      );
      expect(
        loaded.nodes[1].status.lastCompletedAt,
        equals(DateTime.utc(2026, 5, 22, 18)),
      );
      expect(loaded.edges, hasLength(1));
      expect(loaded.edges.single.contribution, EdgeContribution.MANDATORY);
    });

    test('save writes pretty-printed JSON', () async {
      final graph = LakshyaGraph(
        schemaVersion: 1,
        nodes: const [],
        edges: const [],
      );

      await repository.save(graph);

      final contents = await graphFile.readAsString();
      expect(contents, contains('\n'),
          reason: 'expected human-readable formatting');
      expect(contents, contains('"schemaVersion": 1'));
    });

    test('save creates parent directories if missing', () async {
      final nested = File('${tempDir.path}/nested/sub/graph.json');
      final nestedRepo = LocalJsonRepository(file: nested);
      final graph = LakshyaGraph(
        schemaVersion: 1,
        nodes: const [],
        edges: const [],
      );

      await nestedRepo.save(graph);

      expect(await nested.exists(), isTrue);
    });

    test('save then save again overwrites instead of appending', () async {
      final first = LakshyaGraph(
        schemaVersion: 1,
        nodes: [
          NodeElement(
            id: '11111111-1111-1111-1111-111111111111',
            title: 'First',
            status: Status(type: TypeElement.ALWAYS_ON),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      final second = LakshyaGraph(
        schemaVersion: 1,
        nodes: [
          NodeElement(
            id: '22222222-2222-2222-2222-222222222222',
            title: 'Second',
            status: Status(type: TypeElement.ALWAYS_ON),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );

      await repository.save(first);
      await repository.save(second);
      final loaded = await repository.load();

      expect(loaded!.nodes, hasLength(1));
      expect(loaded.nodes.single.title, equals('Second'));
    });
  });
}
