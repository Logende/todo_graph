import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/impact.dart';

void main() {
  group('Impact', () {
    test('has the documented five levels in increasing weight', () {
      expect(Impact.values, equals([
        Impact.minimal,
        Impact.low,
        Impact.medium,
        Impact.high,
        Impact.critical,
      ]));
      var previousWeight = 0.0;
      for (final level in Impact.values) {
        expect(level.weight, greaterThan(previousWeight));
        previousWeight = level.weight;
      }
    });

    test('round-trips via toJsonValue / fromJsonValue', () {
      for (final level in Impact.values) {
        expect(Impact.fromJsonValue(level.toJsonValue()), equals(level));
      }
    });

    test('rejects an unknown value', () {
      expect(() => Impact.fromJsonValue('legendary'),
          throwsFormatException);
    });
  });
}
