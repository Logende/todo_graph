import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/activation_window.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/node_status.dart';

void main() {
  group('NodeStatus composite', () {
    final now = DateTime.utc(2026, 5, 24, 12);

    test('alwaysOnBackground is always-active with no completion', () {
      expect(NodeStatus.alwaysOnBackground.activation, isA<AlwaysActive>());
      expect(NodeStatus.alwaysOnBackground.completion, isNull);
      expect(NodeStatus.alwaysOnBackground.isOngoingAt(now), isTrue);
    });

    test('markCompletedAt is a no-op on a background goal', () {
      final next = NodeStatus.alwaysOnBackground.markCompletedAt(now);
      expect(next, equals(NodeStatus.alwaysOnBackground));
    });

    test('oneTime factory wires always-active + OneTimeCompletion', () {
      final s = NodeStatus.oneTime();
      expect(s.activation, isA<AlwaysActive>());
      expect(s.completion, isA<OneTimeCompletion>());
      expect(s.isOngoingAt(now), isTrue);
      final done = s.markCompletedAt(now);
      expect(done.isOngoingAt(now), isFalse);
      expect((done.completion as OneTimeCompletion).completedAt, equals(now));
    });

    test('periodic factory exposes relative cool-down', () {
      final s = NodeStatus.periodic(
        intervalDaysSinceLastCompletion: 3,
        lastCompletedAt: DateTime.utc(2026, 5, 22),
      );
      expect(s.isOngoingAt(DateTime.utc(2026, 5, 24)), isFalse);
      expect(s.isOngoingAt(DateTime.utc(2026, 5, 25)), isTrue);
      final done = s.markCompletedAt(DateTime.utc(2026, 5, 25, 12));
      expect((done.completion as PeriodicCompletion).lastCompletedAt,
          equals(DateTime.utc(2026, 5, 25, 12)));
    });

    test('bounded + nTimes combines an active window with a count', () {
      final s = NodeStatus.bounded(
        activeFrom: DateTime.utc(2026, 5, 1),
        activeUntil: DateTime.utc(2026, 6, 1),
        completion: const NTimesCompletion(targetCount: 3),
      );
      expect(s.isOngoingAt(DateTime.utc(2026, 4, 15)), isFalse,
          reason: 'before activation window');
      expect(s.isOngoingAt(DateTime.utc(2026, 5, 24)), isTrue,
          reason: 'inside window, n-times not yet exhausted');

      var current = s;
      for (var i = 0; i < 3; i++) {
        current = current.markCompletedAt(DateTime.utc(2026, 5, 24));
      }
      expect(current.isOngoingAt(DateTime.utc(2026, 5, 24)), isFalse,
          reason: 'exhausted inside window -> no longer ongoing');
      expect(
          (current.completion as NTimesCompletion).completedCount, equals(3));

      // Outside the window, the same status is also not ongoing — even if
      // there were still completions left.
      final outsideWindow = NodeStatus.bounded(
        activeFrom: DateTime.utc(2026, 5, 1),
        activeUntil: DateTime.utc(2026, 6, 1),
        completion: const NTimesCompletion(targetCount: 3),
      );
      expect(outsideWindow.isOngoingAt(DateTime.utc(2026, 7, 1)), isFalse);
    });

    test('round-trips through json including the bounded-only window case',
        () {
      final variants = <NodeStatus>[
        NodeStatus.alwaysOnBackground,
        NodeStatus.oneTime(completedAt: DateTime.utc(2026, 5, 24, 10)),
        NodeStatus.nTimes(targetCount: 5, completedCount: 2),
        NodeStatus.periodic(
          intervalDaysSinceLastCompletion: 7,
          lastCompletedAt: DateTime.utc(2026, 5, 17),
        ),
        NodeStatus.bounded(
          activeFrom: DateTime.utc(2026, 5, 1),
          activeUntil: DateTime.utc(2026, 6, 1),
        ),
        NodeStatus.bounded(
          activeFrom: DateTime.utc(2026, 5, 1),
          activeUntil: DateTime.utc(2026, 6, 1),
          completion: const NTimesCompletion(targetCount: 3),
        ),
      ];
      for (final original in variants) {
        expect(NodeStatus.fromJson(original.toJson()), equals(original));
      }
    });

    test('rejects a status missing the required activation field', () {
      expect(
        () => NodeStatus.fromJson({'completion': {'kind': 'one_time'}}),
        throwsFormatException,
      );
    });
  });
}
