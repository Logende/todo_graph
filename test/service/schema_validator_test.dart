import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/edge.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/schema_validator.dart';

void main() {
  late SchemaValidator validator;

  setUpAll(() {
    final schemaText =
        File('schema/lakshya.schema.json').readAsStringSync();
    validator = SchemaValidator.fromString(schemaText);
  });

  group('SchemaValidator', () {
    test('accepts an empty graph', () {
      const empty = LakshyaGraph.empty();
      expect(() => validator.validateOrThrow(empty.toJson()),
          returnsNormally);
    });

    test('accepts a populated graph emitted by the hand-written model', () {
      final graph = LakshyaGraph(
        nodes: [
          Node(
            id: '11111111-1111-1111-1111-111111111111',
            title: 'Health',
            status: NodeStatus.alwaysOnBackground,
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: '22222222-2222-2222-2222-222222222222',
            title: 'Push day',
            status: NodeStatus.periodic(
              intervalDaysSinceLastCompletion: 3,
              lastCompletedAt: DateTime.utc(2026, 5, 22, 18),
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

      expect(() => validator.validateOrThrow(graph.toJson()),
          returnsNormally);
    });

    test('rejects a document missing the required nodes field', () {
      final bad = {
        'schemaVersion': 1,
        'edges': <Map<String, dynamic>>[],
      };
      expect(() => validator.validateOrThrow(bad),
          throwsA(isA<SchemaValidationException>()));
    });

    test('rejects a node with an unknown status type', () {
      final bad = {
        'schemaVersion': 1,
        'nodes': [
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'title': 'Bad',
            'status': {'type': 'invented_kind'},
            'createdAt': '2026-05-24T00:00:00.000Z',
          },
        ],
        'edges': <Map<String, dynamic>>[],
      };
      expect(() => validator.validateOrThrow(bad),
          throwsA(isA<SchemaValidationException>()));
    });

    test('rejects a node missing required title', () {
      final bad = {
        'schemaVersion': 1,
        'nodes': [
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'status': {'type': 'always_on'},
            'createdAt': '2026-05-24T00:00:00.000Z',
          },
        ],
        'edges': <Map<String, dynamic>>[],
      };
      expect(() => validator.validateOrThrow(bad),
          throwsA(isA<SchemaValidationException>()));
    });

    test('rejects an edge with an unknown contribution', () {
      final bad = {
        'schemaVersion': 1,
        'nodes': <Map<String, dynamic>>[],
        'edges': [
          {
            'id': '33333333-3333-3333-3333-333333333333',
            'childId': '22222222-2222-2222-2222-222222222222',
            'parentId': '11111111-1111-1111-1111-111111111111',
            'contribution': 'sometimes',
          },
        ],
      };
      expect(() => validator.validateOrThrow(bad),
          throwsA(isA<SchemaValidationException>()));
    });

    test('isValid returns true/false without throwing', () {
      const empty = LakshyaGraph.empty();
      expect(validator.isValid(empty.toJson()), isTrue);
      expect(validator.isValid({'nope': true}), isFalse);
    });
  });
}
