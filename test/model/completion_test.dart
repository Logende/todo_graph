import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/completion.dart';

void main() {
  group('Completion.fromJson dispatch', () {
    test('parses one_time', () {
      final c = Completion.fromJson({'kind': 'one_time'});
      expect(c, isA<OneTimeCompletion>());
      expect((c as OneTimeCompletion).isCompleted, isFalse);
    });

    test('parses one_time with completedAt', () {
      final c = Completion.fromJson({
        'kind': 'one_time',
        'completedAt': '2026-05-24T12:00:00.000Z',
      }) as OneTimeCompletion;
      expect(c.completedAt, equals(DateTime.utc(2026, 5, 24, 12)));
      expect(c.isCompleted, isTrue);
    });

    test('parses n_times', () {
      final c = Completion.fromJson({
        'kind': 'n_times',
        'targetCount': 3,
        'completedCount': 1,
      }) as NTimesCompletion;
      expect(c.targetCount, 3);
      expect(c.completedCount, 1);
      expect(c.remainingCount, 2);
      expect(c.isExhausted, isFalse);
    });

    test('parses periodic', () {
      final c = Completion.fromJson({
        'kind': 'periodic',
        'intervalDaysSinceLastCompletion': 3,
        'lastCompletedAt': '2026-05-22T18:00:00.000Z',
      }) as PeriodicCompletion;
      expect(c.intervalDaysSinceLastCompletion, 3);
      expect(c.nextDueAt(), equals(DateTime.utc(2026, 5, 25, 18)));
      expect(c.isOpenAt(DateTime.utc(2026, 5, 24)), isFalse);
      expect(c.isOpenAt(DateTime.utc(2026, 5, 26)), isTrue);
    });

    test('rejects unknown kind', () {
      expect(
        () => Completion.fromJson({'kind': 'made_up'}),
        throwsFormatException,
      );
    });

    group('isOngoingAt', () {
      final now = DateTime.utc(2026, 5, 24, 12);
      test('one_time ongoing until completed', () {
        expect(const OneTimeCompletion().isOngoingAt(now), isTrue);
        expect(OneTimeCompletion(completedAt: now).isOngoingAt(now), isFalse);
      });
      test('n_times ongoing until exhausted', () {
        expect(
          const NTimesCompletion(targetCount: 3, completedCount: 1)
              .isOngoingAt(now),
          isTrue,
        );
        expect(
          const NTimesCompletion(targetCount: 3, completedCount: 3)
              .isOngoingAt(now),
          isFalse,
        );
      });
      test('periodic ongoing only after the cool-down', () {
        final c = PeriodicCompletion(
          intervalDaysSinceLastCompletion: 3,
          lastCompletedAt: DateTime.utc(2026, 5, 22, 12),
        );
        expect(c.isOngoingAt(DateTime.utc(2026, 5, 24)), isFalse);
        expect(c.isOngoingAt(DateTime.utc(2026, 5, 25, 12)), isTrue);
      });
    });

    group('markCompletedAt', () {
      final now = DateTime.utc(2026, 5, 24, 12);
      test('one_time records completion time', () {
        final next =
            const OneTimeCompletion().markCompletedAt(now) as OneTimeCompletion;
        expect(next.completedAt, equals(now));
      });
      test('n_times increments and records lastCompletedAt', () {
        final next = const NTimesCompletion(targetCount: 3, completedCount: 1)
            .markCompletedAt(now) as NTimesCompletion;
        expect(next.completedCount, 2);
        expect(next.lastCompletedAt, equals(now));
      });
      test('n_times caps at targetCount', () {
        final next = const NTimesCompletion(targetCount: 3, completedCount: 3)
            .markCompletedAt(now) as NTimesCompletion;
        expect(next.completedCount, 3);
      });
      test('periodic resets cool-down', () {
        final next = PeriodicCompletion(
          intervalDaysSinceLastCompletion: 3,
          lastCompletedAt: DateTime.utc(2026, 5, 22),
        ).markCompletedAt(now) as PeriodicCompletion;
        expect(next.lastCompletedAt, equals(now));
        expect(next.nextDueAt(), equals(DateTime.utc(2026, 5, 27, 12)));
      });
    });

    group('markIncomplete', () {
      test('one_time clears completion time', () {
        final next = OneTimeCompletion(
          completedAt: DateTime.utc(2026, 5, 24, 12),
        ).markIncomplete() as OneTimeCompletion;
        expect(next.completedAt, isNull);
      });

      test('n_times decrements and clears timestamp when back at zero', () {
        final next = NTimesCompletion(
          targetCount: 3,
          completedCount: 1,
          lastCompletedAt: DateTime.utc(2026, 5, 24, 12),
        ).markIncomplete() as NTimesCompletion;
        expect(next.completedCount, 0);
        expect(next.lastCompletedAt, isNull);
      });

      test('periodic clears the last completion so it reopens immediately', () {
        final next = PeriodicCompletion(
          intervalDaysSinceLastCompletion: 3,
          lastCompletedAt: DateTime.utc(2026, 5, 22),
        ).markIncomplete() as PeriodicCompletion;
        expect(next.lastCompletedAt, isNull);
      });
    });

    test('all variants round-trip through json', () {
      final variants = <Completion>[
        OneTimeCompletion(completedAt: DateTime.utc(2026, 5, 24, 12)),
        const NTimesCompletion(targetCount: 3, completedCount: 1),
        PeriodicCompletion(
          intervalDaysSinceLastCompletion: 7,
          lastCompletedAt: DateTime.utc(2026, 5, 17),
        ),
      ];
      for (final original in variants) {
        expect(Completion.fromJson(original.toJson()), equals(original));
      }
    });
  });
}
