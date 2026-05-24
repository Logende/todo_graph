import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/node_status.dart';

void main() {
  group('NodeStatus.fromJson dispatch', () {
    test('parses always_on', () {
      final s = NodeStatus.fromJson({'type': 'always_on'});
      expect(s, isA<AlwaysOnStatus>());
      expect(s.type, StatusType.alwaysOn);
    });

    test('parses one_time without completedAt', () {
      final s = NodeStatus.fromJson({'type': 'one_time'});
      expect(s, isA<OneTimeStatus>());
      expect((s as OneTimeStatus).isCompleted, isFalse);
    });

    test('parses one_time with completedAt', () {
      final s = NodeStatus.fromJson({
        'type': 'one_time',
        'completedAt': '2026-05-24T12:00:00.000Z',
      }) as OneTimeStatus;
      expect(s.isCompleted, isTrue);
      expect(s.completedAt, equals(DateTime.utc(2026, 5, 24, 12)));
    });

    test('parses n_times and computes remainingCount and isExhausted', () {
      final s = NodeStatus.fromJson({
        'type': 'n_times',
        'targetCount': 3,
        'completedCount': 1,
      }) as NTimesStatus;
      expect(s.remainingCount, 2);
      expect(s.isExhausted, isFalse);

      const exhausted =
          NTimesStatus(targetCount: 3, completedCount: 3);
      expect(exhausted.isExhausted, isTrue);
      expect(exhausted.remainingCount, 0);
    });

    test('parses periodic and computes nextDueAt relative to lastCompletedAt',
        () {
      final s = NodeStatus.fromJson({
        'type': 'periodic',
        'intervalDaysSinceLastCompletion': 3,
        'lastCompletedAt': '2026-05-22T18:00:00.000Z',
      }) as PeriodicStatus;
      expect(s.intervalDaysSinceLastCompletion, 3);
      expect(s.nextDueAt(), equals(DateTime.utc(2026, 5, 25, 18)));
    });

    test('periodic with no completion is open immediately', () {
      const s =
          PeriodicStatus(intervalDaysSinceLastCompletion: 3);
      expect(s.nextDueAt(), isNull);
      expect(s.isOpenAt(DateTime.utc(2026, 5, 24)), isTrue);
    });

    test('periodic isOpenAt resets relative to the last completion', () {
      final completedAt = DateTime.utc(2026, 5, 22, 18);
      final s = PeriodicStatus(
        intervalDaysSinceLastCompletion: 3,
        lastCompletedAt: completedAt,
      );
      expect(s.isOpenAt(DateTime.utc(2026, 5, 24)), isFalse,
          reason: 'still inside the 3-day cool-down');
      expect(s.isOpenAt(DateTime.utc(2026, 5, 25, 18)), isTrue,
          reason: 'exactly 3 days later, task re-opens');
      expect(s.isOpenAt(DateTime.utc(2026, 5, 26)), isTrue);
    });

    test('parses temporarily_active and checks window membership', () {
      final s = NodeStatus.fromJson({
        'type': 'temporarily_active',
        'activeFrom': '2026-05-01T00:00:00.000Z',
        'activeUntil': '2026-06-01T00:00:00.000Z',
      }) as TemporarilyActiveStatus;

      expect(s.isActiveAt(DateTime.utc(2026, 5, 24)), isTrue);
      expect(s.isActiveAt(DateTime.utc(2026, 4, 30)), isFalse);
      expect(s.isActiveAt(DateTime.utc(2026, 6, 2)), isFalse);
    });

    test('rejects an unknown status type', () {
      expect(
        () => NodeStatus.fromJson({'type': 'something_weird'}),
        throwsFormatException,
      );
    });

    test('rejects a missing status type', () {
      expect(
        () => NodeStatus.fromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });

    test('all variants roundtrip through json', () {
      final variants = <NodeStatus>[
        const AlwaysOnStatus(),
        OneTimeStatus(completedAt: DateTime.utc(2026, 5, 24, 12)),
        const NTimesStatus(targetCount: 3, completedCount: 1),
        PeriodicStatus(
          intervalDaysSinceLastCompletion: 7,
          lastCompletedAt: DateTime.utc(2026, 5, 17),
        ),
        TemporarilyActiveStatus(
          activeFrom: DateTime.utc(2026, 5, 1),
          activeUntil: DateTime.utc(2026, 6, 1),
          completedAt: DateTime.utc(2026, 5, 24),
        ),
      ];

      for (final original in variants) {
        final round = NodeStatus.fromJson(original.toJson());
        expect(round, equals(original),
            reason: '${original.runtimeType} did not roundtrip');
      }
    });
  });
}
