import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/repository/graph_repository.dart';
import 'package:lakshya/repository/shared_preferences_graph_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/builders.dart';

void main() {
  late SharedPreferences prefs;
  late SharedPreferencesGraphRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = SharedPreferencesGraphRepository(preferences: prefs);
  });

  group('SharedPreferencesGraphRepository', () {
    test('implements GraphRepository', () {
      expect(repository, isA<GraphRepository>());
    });

    test('load returns null when nothing is stored', () async {
      expect(await repository.load(), isNull);
    });

    test('save then load returns an equal graph', () async {
      final original = LakshyaGraph(
        nodes: [
          buildNode('root', title: 'All goals achieved'),
          buildNode('health', title: 'Health'),
        ],
        edges: [buildEdge('e1', from: 'health', to: 'root')],
      );

      await repository.save(original);
      final loaded = await repository.load();

      expect(loaded, equals(original));
    });

    test('save then save again overwrites instead of merging', () async {
      final first = LakshyaGraph(
        nodes: [buildNode('first')],
        edges: const [],
      );
      final second = LakshyaGraph(
        nodes: [buildNode('second')],
        edges: const [],
      );

      await repository.save(first);
      await repository.save(second);
      final loaded = await repository.load();

      expect(loaded!.nodes, hasLength(1));
      expect(loaded.nodes.single.id, equals('second'));
    });

    test('save stores pretty-printed JSON under the documented key',
        () async {
      const graph = LakshyaGraph.empty();
      await repository.save(graph);

      final raw =
          prefs.getString(SharedPreferencesGraphRepository.storageKey);
      expect(raw, isNotNull);
      expect(raw, contains('\n'), reason: 'pretty-printed for debuggability');
      final decoded = json.decode(raw!) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], equals(1));
    });
  });
}
