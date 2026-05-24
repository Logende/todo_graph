import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/activation_window.dart';

void main() {
  group('ActivationWindow.fromJson dispatch', () {
    test('parses always_active', () {
      final w = ActivationWindow.fromJson({'kind': 'always_active'});
      expect(w, isA<AlwaysActive>());
    });

    test('parses bounded with from and until', () {
      final w = ActivationWindow.fromJson({
        'kind': 'bounded',
        'activeFrom': '2026-05-01T00:00:00.000Z',
        'activeUntil': '2026-06-01T00:00:00.000Z',
      }) as BoundedActive;
      expect(w.activeFrom, equals(DateTime.utc(2026, 5, 1)));
      expect(w.activeUntil, equals(DateTime.utc(2026, 6, 1)));
    });

    test('rejects unknown kind', () {
      expect(
        () => ActivationWindow.fromJson({'kind': 'forever_and_ever'}),
        throwsFormatException,
      );
    });

    test('rejects missing kind', () {
      expect(
        () => ActivationWindow.fromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });

    test('always_active.isActiveAt is true regardless of time', () {
      expect(const AlwaysActive().isActiveAt(DateTime.utc(2026, 5, 24)),
          isTrue);
      expect(const AlwaysActive().isActiveAt(DateTime.utc(1000, 1, 1)),
          isTrue);
    });

    test('bounded.isActiveAt respects the window inclusively', () {
      final w = BoundedActive(
        activeFrom: DateTime.utc(2026, 5, 1),
        activeUntil: DateTime.utc(2026, 6, 1),
      );
      expect(w.isActiveAt(DateTime.utc(2026, 5, 1)), isTrue);
      expect(w.isActiveAt(DateTime.utc(2026, 5, 24)), isTrue);
      expect(w.isActiveAt(DateTime.utc(2026, 6, 1)), isTrue);
      expect(w.isActiveAt(DateTime.utc(2026, 4, 30)), isFalse);
      expect(w.isActiveAt(DateTime.utc(2026, 6, 2)), isFalse);
    });

    test('bounded constructor rejects an end-before-start window', () {
      expect(
        () => BoundedActive(
          activeFrom: DateTime.utc(2026, 6, 1),
          activeUntil: DateTime.utc(2026, 5, 1),
        ),
        throwsArgumentError,
      );
    });

    test('bounded allows start == end (instantaneous window)', () {
      final instant = DateTime.utc(2026, 5, 24, 12);
      expect(
        () => BoundedActive(activeFrom: instant, activeUntil: instant),
        returnsNormally,
      );
    });

    test('bounded.fromJson surfaces an invalid window as FormatException',
        () {
      expect(
        () => ActivationWindow.fromJson({
          'kind': 'bounded',
          'activeFrom': '2026-06-01T00:00:00.000Z',
          'activeUntil': '2026-05-01T00:00:00.000Z',
        }),
        throwsFormatException,
      );
    });

    test('both variants round-trip through json', () {
      final variants = <ActivationWindow>[
        const AlwaysActive(),
        BoundedActive(
          activeFrom: DateTime.utc(2026, 5, 1),
          activeUntil: DateTime.utc(2026, 6, 1),
        ),
      ];
      for (final original in variants) {
        final round = ActivationWindow.fromJson(original.toJson());
        expect(round, equals(original));
      }
    });
  });
}
