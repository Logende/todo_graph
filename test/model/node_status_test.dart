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

    group('isOngoingAt', () {
      final now = DateTime.utc(2026, 5, 24, 12);
      test('always_on is always ongoing', () {
        expect(const AlwaysOnStatus().isOngoingAt(now), isTrue);
      });
      test('one_time is ongoing until completed', () {
        expect(const OneTimeStatus().isOngoingAt(now), isTrue);
        expect(OneTimeStatus(completedAt: now).isOngoingAt(now), isFalse);
      });
      test('n_times is ongoing until exhausted', () {
        expect(const NTimesStatus(targetCount: 3, completedCount: 1)
            .isOngoingAt(now), isTrue);
        expect(const NTimesStatus(targetCount: 3, completedCount: 3)
            .isOngoingAt(now), isFalse);
      });
      test('periodic is ongoing only after the cool-down', () {
        final s = PeriodicStatus(
          intervalDaysSinceLastCompletion: 3,
          lastCompletedAt: DateTime.utc(2026, 5, 22, 12),
        );
        expect(s.isOngoingAt(DateTime.utc(2026, 5, 24)), isFalse);
        expect(s.isOngoingAt(DateTime.utc(2026, 5, 25, 12)), isTrue);
      });
      test('temporarily_active is ongoing only inside window and not completed',
          () {
        final s = TemporarilyActiveStatus(
          activeFrom: DateTime.utc(2026, 5, 1),
          activeUntil: DateTime.utc(2026, 6, 1),
        );
        expect(s.isOngoingAt(DateTime.utc(2026, 5, 24)), isTrue);
        expect(s.isOngoingAt(DateTime.utc(2026, 4, 1)), isFalse);
        final completed = TemporarilyActiveStatus(
          activeFrom: s.activeFrom,
          activeUntil: s.activeUntil,
          completedAt: DateTime.utc(2026, 5, 20),
        );
        expect(completed.isOngoingAt(DateTime.utc(2026, 5, 24)), isFalse);
      });
    });

    group('markCompletedAt', () {
      final now = DateTime.utc(2026, 5, 24, 12);

      test('always_on returns the same instance', () {
        const s = AlwaysOnStatus();
        expect(s.markCompletedAt(now), same(s));
      });

      test('one_time records completion time', () {
        final completed =
            const OneTimeStatus().markCompletedAt(now) as OneTimeStatus;
        expect(completed.completedAt, equals(now));
      });

      test('n_times increments completedCount and records lastCompletedAt',
          () {
        final next = const NTimesStatus(targetCount: 3, completedCount: 1)
            .markCompletedAt(now) as NTimesStatus;
        expect(next.completedCount, 2);
        expect(next.lastCompletedAt, equals(now));
      });

      test('n_times caps completedCount at targetCount', () {
        final next = const NTimesStatus(targetCount: 3, completedCount: 3)
            .markCompletedAt(now) as NTimesStatus;
        expect(next.completedCount, 3);
      });

      test('periodic resets cool-down by recording new lastCompletedAt', () {
        final next = PeriodicStatus(
          intervalDaysSinceLastCompletion: 3,
          lastCompletedAt: DateTime.utc(2026, 5, 22),
        ).markCompletedAt(now) as PeriodicStatus;
        expect(next.intervalDaysSinceLastCompletion, 3);
        expect(next.lastCompletedAt, equals(now));
        expect(next.nextDueAt(), equals(DateTime.utc(2026, 5, 27, 12)));
      });

      test('temporarily_active preserves window and records completion', () {
        final s = TemporarilyActiveStatus(
          activeFrom: DateTime.utc(2026, 5, 1),
          activeUntil: DateTime.utc(2026, 6, 1),
        );
        final next = s.markCompletedAt(now) as TemporarilyActiveStatus;
        expect(next.activeFrom, equals(s.activeFrom));
        expect(next.activeUntil, equals(s.activeUntil));
        expect(next.completedAt, equals(now));
      });
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
