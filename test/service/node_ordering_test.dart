import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/impact.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_relationship.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/node_ordering.dart';

Node _node(
  String id, {
  DateTime? deadline,
  Impact? impact,
  DateTime? createdAt,
}) =>
    Node(
      id: id,
      title: id,
      status: NodeStatus.alwaysOnBackground,
      deadline: deadline,
      impact: impact,
      createdAt: createdAt ?? DateTime.utc(2026, 5, 24),
    );

void main() {
  final now = DateTime.utc(2026, 5, 24, 12);
  const ordering = NodeOrdering();

  group('Urgent tier (deadlines within the configured window)', () {
    test('promotes deadlines inside the default 3-day window above everything',
        () {
      final later = _node('later',
          deadline: DateTime.utc(2026, 6, 10), impact: Impact.critical);
      final urgent = _node('urgent',
          deadline: DateTime.utc(2026, 5, 26), impact: Impact.low);
      final result =
          ordering.defaultOrder([later, urgent], now: now);
      expect(result.first.id, equals('urgent'),
          reason: 'within 3-day window beats a critical impact later');
    });

    test('within the urgent window, earlier deadline ranks first', () {
      final twoDays = _node('two', deadline: DateTime.utc(2026, 5, 26));
      final oneDay = _node('one', deadline: DateTime.utc(2026, 5, 25));
      final result =
          ordering.defaultOrder([twoDays, oneDay], now: now);
      expect(result.map((n) => n.id), equals(['one', 'two']));
    });

    test('the urgent window is configurable via [urgentWindow]', () {
      final fiveDaysOut =
          _node('out', deadline: DateTime.utc(2026, 5, 29));
      final result = NodeOrdering(urgentWindow: const Duration(days: 7))
          .defaultOrder([fiveDaysOut], now: now);
      expect(result.single.id, equals('out'));
    });
  });

  group('Non-urgent tier ordering', () {
    test('non-urgent tasks: earlier deadlines first, then higher impact', () {
      final juneEarly = _node('june-early',
          deadline: DateTime.utc(2026, 6, 5), impact: Impact.low);
      final juneLater = _node('june-later',
          deadline: DateTime.utc(2026, 6, 10), impact: Impact.high);
      final noDeadlineCritical =
          _node('no-dl-critical', impact: Impact.critical);
      final noDeadlineMinimal =
          _node('no-dl-minimal', impact: Impact.minimal);

      final result = ordering.defaultOrder([
        noDeadlineMinimal,
        juneLater,
        noDeadlineCritical,
        juneEarly,
      ], now: now);

      expect(
        result.map((n) => n.id),
        equals(['june-early', 'june-later', 'no-dl-critical', 'no-dl-minimal']),
      );
    });

    test('createdAt breaks ties for otherwise equal nodes', () {
      final newer =
          _node('newer', createdAt: DateTime.utc(2026, 5, 24));
      final older =
          _node('older', createdAt: DateTime.utc(2026, 5, 20));
      final result = ordering.defaultOrder([newer, older], now: now);
      expect(result.map((n) => n.id), equals(['older', 'newer']));
    });
  });

  group('Importance relationships override score-based ordering', () {
    test('moreImportantThan lifts the source above the target', () {
      final a = _node('a', impact: Impact.minimal);
      final b = _node('b', impact: Impact.critical);
      final result = ordering.defaultOrder(
        [a, b],
        now: now,
        relationships: const [
          NodeRelationship(
            id: 'r1',
            fromNodeId: 'a',
            toNodeId: 'b',
            kind: RelationshipKind.moreImportantThan,
          ),
        ],
      );
      expect(result.map((n) => n.id), equals(['a', 'b']));
    });

    test('lessImportantThan lifts the target above the source', () {
      final a = _node('a', impact: Impact.critical);
      final b = _node('b', impact: Impact.critical);
      final result = ordering.defaultOrder(
        [a, b],
        now: now,
        relationships: const [
          NodeRelationship(
            id: 'r1',
            fromNodeId: 'a',
            toNodeId: 'b',
            kind: RelationshipKind.lessImportantThan,
          ),
        ],
      );
      expect(result.map((n) => n.id), equals(['b', 'a']),
          reason: '"a less important than b" => b above a');
    });

    test('chained importance relationships compose', () {
      final a = _node('a', impact: Impact.minimal);
      final b = _node('b', impact: Impact.minimal);
      final c = _node('c', impact: Impact.critical);
      final result = ordering.defaultOrder(
        [c, b, a],
        now: now,
        relationships: const [
          NodeRelationship(
            id: 'r1',
            fromNodeId: 'a',
            toNodeId: 'b',
            kind: RelationshipKind.moreImportantThan,
          ),
          NodeRelationship(
            id: 'r2',
            fromNodeId: 'b',
            toNodeId: 'c',
            kind: RelationshipKind.moreImportantThan,
          ),
        ],
      );
      expect(result.map((n) => n.id), equals(['a', 'b', 'c']));
    });

    test('alternativeTo has no effect on ordering', () {
      final a = _node('a', impact: Impact.critical);
      final b = _node('b', impact: Impact.minimal);
      final result = ordering.defaultOrder(
        [a, b],
        now: now,
        relationships: const [
          NodeRelationship(
            id: 'r1',
            fromNodeId: 'a',
            toNodeId: 'b',
            kind: RelationshipKind.alternativeTo,
          ),
        ],
      );
      expect(result.map((n) => n.id), equals(['a', 'b']),
          reason: 'alternativeTo is symmetric; ordering follows impact only');
    });

    test('importance relationships referencing unknown ids are ignored', () {
      final a = _node('a', impact: Impact.minimal);
      final b = _node('b', impact: Impact.critical);
      final result = ordering.defaultOrder(
        [a, b],
        now: now,
        relationships: const [
          NodeRelationship(
            id: 'r1',
            fromNodeId: 'ghost',
            toNodeId: 'a',
            kind: RelationshipKind.moreImportantThan,
          ),
        ],
      );
      expect(result.map((n) => n.id), equals(['b', 'a']));
    });
  });

  test('empty input returns empty', () {
    expect(ordering.defaultOrder(const [], now: now), isEmpty);
  });
}
