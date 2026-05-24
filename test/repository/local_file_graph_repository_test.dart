import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/repository/graph_repository.dart';
import 'package:lakshya/repository/local_file_graph_repository.dart';

import '../support/builders.dart';

void main() {
  late Directory tempDir;
  late LocalFileGraphRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lakshya_repo_test');
    repository = LocalFileGraphRepository(
      file: File('${tempDir.path}/graph.json'),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalFileGraphRepository', () {
    test('implements GraphRepository', () {
      expect(repository, isA<GraphRepository>());
    });

    test('load returns null when the file does not exist', () async {
      expect(await repository.load(), isNull);
    });

    test('save then load returns an equal graph', () async {
      final graph = LakshyaGraph(
        nodes: [buildNode('root', title: 'All goals achieved')],
        edges: const [],
      );

      await repository.save(graph);
      final loaded = await repository.load();

      expect(loaded, equals(graph));
    });

    test('save creates the parent directory when needed', () async {
      final nested = LocalFileGraphRepository(
        file: File('${tempDir.path}/nested/folder/graph.json'),
      );
      final graph = LakshyaGraph(
        nodes: [buildNode('root')],
        edges: const [],
      );

      await nested.save(graph);

      expect(await File('${tempDir.path}/nested/folder/graph.json').exists(),
          isTrue);
    });
  });
}
