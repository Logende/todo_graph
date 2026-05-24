import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/activation_window.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/impact.dart';
import 'package:lakshya/model/node_relationship.dart';
import 'package:lakshya/service/asset_seed_loader.dart';
import 'package:lakshya/service/schema_validator.dart';

void main() {
  late SchemaValidator validator;
  late String seedJson;

  setUpAll(() {
    final schemaText =
        File('schema/lakshya.schema.json').readAsStringSync();
    validator = SchemaValidator.fromString(schemaText);
    seedJson = File('assets/example_seed.json').readAsStringSync();
  });

  group('AssetSeedLoader', () {
    test('parses and validates the bundled example seed', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);

      expect(graph.nodes, isNotEmpty);
      expect(graph.edges, isNotEmpty);
      expect(graph.settings?.rootNodeId, equals('all-goals-achieved'));
    });

    test('rejects an invalid seed string with SchemaValidationException', () {
      final loader = AssetSeedLoader(validator: validator);
      expect(
        () => loader.parse('{"schemaVersion": 1}'),
        throwsA(isA<SchemaValidationException>()),
      );
    });

    test('example seed contains every node listed in the README spec', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final titles = graph.nodes.map((n) => n.title).toSet();
      const expected = {
        'All goals achieved',
        'Health',
        'Sleep',
        'Food',
        'Fitness',
        'Make new gym plan',
        'Take new gym measurement',
        'Workout',
        'Push day',
        'Pull day',
        'Family',
        'Work',
        'Finish PhD',
        'Finish graduate school',
        'Do Coursera course',
        'Join 6-credits class',
        'Do other seminar',
        'Publish enough papers',
        'LLM JSON schema paper',
        'Schema orchestrator paper',
        'Write dissertation',
        'Cooperations',
        'Respond to Watzenborn',
        'Leisure',
        'Personal development',
        'Read Buddha book',
        'Game development',
        'Play Veiled Kingdom at university',
        'Personal life tasks',
        'Tax report',
      };
      expect(titles.containsAll(expected), isTrue,
          reason: 'missing: ${expected.difference(titles)}');
    });

    test('Push day and Pull day are 3-day periodic tasks', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      for (final id in ['push-day', 'pull-day']) {
        final node = graph.nodes.firstWhere((n) => n.id == id);
        final completion = node.status.completion as PeriodicCompletion;
        expect(completion.intervalDaysSinceLastCompletion, equals(3));
      }
    });

    test('Tax report recurs yearly', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final tax = graph.nodes.firstWhere((n) => n.id == 'tax-report');
      final c = tax.status.completion as PeriodicCompletion;
      expect(c.intervalDaysSinceLastCompletion, equals(365));
    });

    test('Cooperations has a bounded activation window', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final cooperations =
          graph.nodes.firstWhere((n) => n.id == 'cooperations');
      expect(cooperations.status.activation, isA<BoundedActive>());
    });

    test('Respond to Watzenborn has a deadline and a high impact rating', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final urgent =
          graph.nodes.firstWhere((n) => n.id == 'respond-to-watzenborn');
      expect(urgent.deadline, isNotNull);
      expect(urgent.impact, equals(Impact.high));
    });

    test(
        'the two paper nodes are linked as alternatives so completing one '
        'closes the other', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final hasAlternative = graph.relationships.any((r) =>
          r.kind == RelationshipKind.alternativeTo &&
          ((r.fromNodeId == 'llm-json-schema-paper' &&
                  r.toNodeId == 'schema-orchestrator-paper') ||
              (r.fromNodeId == 'schema-orchestrator-paper' &&
                  r.toNodeId == 'llm-json-schema-paper')));
      expect(hasAlternative, isTrue);
    });

    test('the two paper nodes link to publish-enough-papers as helpful', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      for (final child in const [
        'llm-json-schema-paper',
        'schema-orchestrator-paper'
      ]) {
        final edge = graph.edges.firstWhere(
          (e) =>
              e.childId == child && e.parentId == 'publish-enough-papers',
        );
        expect(edge.contribution, equals(Contribution.helpful));
      }
    });

    test('Play Veiled Kingdom is helpful for Game development', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final edge = graph.edges.firstWhere(
        (e) =>
            e.childId == 'play-veiled-kingdom-at-university' &&
            e.parentId == 'game-development',
      );
      expect(edge.contribution, equals(Contribution.helpful));
    });

    test('every non-root node has at least one parent edge', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final rootId = graph.settings!.rootNodeId;
      for (final node in graph.nodes) {
        if (node.id == rootId) continue;
        final hasParent = graph.edges.any((e) => e.childId == node.id);
        expect(hasParent, isTrue, reason: '${node.title} has no parent');
      }
    });
  });
}
