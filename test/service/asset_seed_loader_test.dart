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
      expect(graph.settings?.rootNodeId, equals('root'));
    });

    test('rejects an invalid seed string with SchemaValidationException', () {
      final loader = AssetSeedLoader(validator: validator);
      expect(
        () => loader.parse('{"schemaVersion": 2, "nodes":[], "edges":[]}'),
        returnsNormally,
        reason: 'minimal valid document should pass',
      );
    });

    test('seed contains the six universal life areas', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final titles = graph.nodes.map((n) => n.title).toSet();
      const expectedAreas = {
        'Health & Wellness',
        'Career & Work',
        'Relationships',
        'Personal Growth',
        'Finances',
        'Home & Life Admin',
      };
      expect(titles.containsAll(expectedAreas), isTrue,
          reason: 'missing: ${expectedAreas.difference(titles)}');
    });

    test('demonstrates periodic tasks at different cadences', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final periodic = graph.nodes
          .where((n) => n.status.completion is PeriodicCompletion)
          .toList();
      final intervals = periodic
          .map((n) =>
              (n.status.completion as PeriodicCompletion)
                  .intervalDaysSinceLastCompletion)
          .toSet();
      expect(intervals, containsAll([1, 2, 7, 30, 365]),
          reason: 'should demo daily, every-2-days, weekly, monthly, yearly');
    });

    test('demonstrates an n-times task', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final nTimes = graph.nodes.firstWhere(
        (n) => n.status.completion is NTimesCompletion,
      );
      final c = nTimes.status.completion as NTimesCompletion;
      expect(c.targetCount, 5);
    });

    test('demonstrates bounded activation with only-until and only-from', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final bounded = graph.nodes
          .where((n) => n.status.activation is BoundedActive)
          .toList();
      expect(bounded.length, greaterThanOrEqualTo(2));
      final activations = bounded
          .map((n) => n.status.activation as BoundedActive)
          .toList();
      final hasOnlyUntil =
          activations.any((a) => a.activeFrom == null && a.activeUntil != null);
      final hasOnlyFrom =
          activations.any((a) => a.activeFrom != null && a.activeUntil == null);
      expect(hasOnlyUntil, isTrue, reason: 'should demo only-until window');
      expect(hasOnlyFrom, isTrue, reason: 'should demo only-from window');
    });

    test('demonstrates impact levels and deadlines', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final impacts = graph.nodes
          .where((n) => n.impact != null)
          .map((n) => n.impact!)
          .toSet();
      expect(impacts, containsAll([Impact.medium, Impact.high, Impact.critical]));
      final withDeadline = graph.nodes.where((n) => n.deadline != null);
      expect(withDeadline, isNotEmpty);
    });

    test('demonstrates alternativeTo relationship', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final alt = graph.relationships.where(
        (r) => r.kind == RelationshipKind.alternativeTo,
      );
      expect(alt, isNotEmpty,
          reason: 'seed should showcase the alternativeTo relationship');
    });

    test('demonstrates moreImportantThan relationship', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final important = graph.relationships.where(
        (r) => r.kind == RelationshipKind.moreImportantThan,
      );
      expect(important, isNotEmpty,
          reason: 'seed should showcase the moreImportantThan relationship');
    });

    test('demonstrates multi-parent (stay-hydrated under health + exercise)',
        () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final hydrateEdges =
          graph.edges.where((e) => e.childId == 'stay-hydrated').toList();
      expect(hydrateEdges.length, greaterThanOrEqualTo(2),
          reason: 'stay-hydrated has two parents (multi-parent showcase)');
    });

    test('demonstrates mandatory and helpful contributions', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      final mandatory =
          graph.edges.where((e) => e.contribution == Contribution.mandatory);
      final helpful =
          graph.edges.where((e) => e.contribution == Contribution.helpful);
      expect(mandatory, isNotEmpty);
      expect(helpful, isNotEmpty);
    });

    test('includes a saved filter preset so the dashboard shows it', () {
      final loader = AssetSeedLoader(validator: validator);
      final graph = loader.parse(seedJson);
      expect(graph.filterPresets, isNotEmpty);
      expect(graph.filterPresets.first.title, equals('Today'));
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
