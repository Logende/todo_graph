import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/edge.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/graph_io.dart';
import 'package:lakshya/service/schema_validator.dart';

void main() {
  late SchemaValidator validator;
  late GraphIo io;

  setUpAll(() {
    final schemaText =
        File('schema/lakshya.schema.json').readAsStringSync();
    validator = SchemaValidator.fromString(schemaText);
    io = GraphIo(validator: validator);
  });

  group('GraphIo.exportToJson', () {
    test('writes a pretty-printed JSON document', () {
      const graph = LakshyaGraph.empty();
      final out = io.exportToJson(graph);
      expect(out, contains('\n'));
      expect(out, contains('"schemaVersion": 1'));
    });

    test('round trips through importFromJson', () {
      final graph = LakshyaGraph(
        nodes: [
          Node(
            id: '11111111-1111-1111-1111-111111111111',
            title: 'Health',
            status: const AlwaysOnStatus(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
        ],
        edges: const [],
      );
      final loaded = io.importFromJson(io.exportToJson(graph));
      expect(loaded, equals(graph));
    });
  });

  group('GraphIo.importFromJson', () {
    test('rejects invalid JSON syntax', () {
      expect(
        () => io.importFromJson('{not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-object root', () {
      expect(
        () => io.importFromJson('[]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a document that fails schema validation', () {
      expect(
        () => io.importFromJson('{"schemaVersion": 1}'),
        throwsA(isA<SchemaValidationException>()),
      );
    });

    test(
        'rejects a document with an unknown status type via schema validation',
        () {
      const invalid = '''
{
  "schemaVersion": 1,
  "nodes": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "title": "Bad",
      "status": {"type": "made_up"},
      "createdAt": "2026-05-24T00:00:00.000Z"
    }
  ],
  "edges": []
}
''';
      expect(
        () => io.importFromJson(invalid),
        throwsA(isA<SchemaValidationException>()),
      );
    });

    test('accepts a document that passes validation', () {
      final graph = LakshyaGraph(
        nodes: [
          Node(
            id: '11111111-1111-1111-1111-111111111111',
            title: 'Health',
            status: const AlwaysOnStatus(),
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: '22222222-2222-2222-2222-222222222222',
            title: 'Pushday',
            status: PeriodicStatus(
              intervalDaysSinceLastCompletion: 3,
              lastCompletedAt: DateTime.utc(2026, 5, 22),
            ),
            createdAt: DateTime.utc(2026, 5, 24),
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
      final restored = io.importFromJson(io.exportToJson(graph));
      expect(restored, equals(graph));
    });
  });
}
