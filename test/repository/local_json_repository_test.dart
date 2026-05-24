import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/edge.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/repository/graph_repository.dart';
import 'package:lakshya/repository/local_json_repository.dart';
import 'package:lakshya/service/schema_validator.dart';

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

    test('save then load returns an equal graph', () async {
      final original = LakshyaGraph(
        nodes: [
          Node(
            id: '11111111-1111-1111-1111-111111111111',
            title: 'Health',
            status: const AlwaysOnStatus(),
            createdAt: DateTime.utc(2026, 5, 24, 10),
          ),
          Node(
            id: '22222222-2222-2222-2222-222222222222',
            title: 'Push day',
            status: PeriodicStatus(
              intervalDaysSinceLastCompletion: 3,
              lastCompletedAt: DateTime.utc(2026, 5, 22, 18),
            ),
            createdAt: DateTime.utc(2026, 5, 24, 10),
          ),
        ],
        edges: const [
          Edge(
            id: '33333333-3333-3333-3333-333333333333',
            childId: '22222222-2222-2222-2222-222222222222',
            parentId: '11111111-1111-1111-1111-111111111111',
            contribution: Contribution.mandatory,
          ),
        ],
      );

      await repository.save(original);
      final loaded = await repository.load();

      expect(loaded, equals(original));
    });

    test('save writes pretty-printed JSON', () async {
      const graph = LakshyaGraph.empty();

      await repository.save(graph);

      final contents = await graphFile.readAsString();
      expect(contents, contains('\n'),
          reason: 'expected human-readable formatting');
      expect(contents, contains('"schemaVersion": 1'));
    });

    test('save creates parent directories if missing', () async {
      final nested = File('${tempDir.path}/nested/sub/graph.json');
      final nestedRepo = LocalJsonRepository(file: nested);
      const graph = LakshyaGraph.empty();

      await nestedRepo.save(graph);

      expect(await nested.exists(), isTrue);
    });

    test(
        'load throws SchemaValidationException when the file fails validation '
        'and a validator is wired in', () async {
      final schemaText =
          File('schema/lakshya.schema.json').readAsStringSync();
      final validatingRepo = LocalJsonRepository(
        file: graphFile,
        validator: SchemaValidator.fromString(schemaText),
      );
      await graphFile.writeAsString('{"schemaVersion": 1}');

      expect(
        validatingRepo.load,
        throwsA(isA<SchemaValidationException>()),
      );
    });

    test(
        'load succeeds when the file is valid and a validator is wired in',
        () async {
      final schemaText =
          File('schema/lakshya.schema.json').readAsStringSync();
      final validatingRepo = LocalJsonRepository(
        file: graphFile,
        validator: SchemaValidator.fromString(schemaText),
      );
      const graph = LakshyaGraph.empty();
      await validatingRepo.save(graph);

      final loaded = await validatingRepo.load();
      expect(loaded, equals(graph));
    });

    test('save then save again overwrites instead of appending', () async {
      final first = LakshyaGraph(
        nodes: [
          Node(
            id: '11111111-1111-1111-1111-111111111111',
            title: 'First',
            status: const AlwaysOnStatus(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      final second = LakshyaGraph(
        nodes: [
          Node(
            id: '22222222-2222-2222-2222-222222222222',
            title: 'Second',
            status: const AlwaysOnStatus(),
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
