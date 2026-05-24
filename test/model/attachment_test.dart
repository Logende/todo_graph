import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/attachment.dart';

void main() {
  group('Attachment.fromJson dispatch', () {
    test('parses a url attachment', () {
      final a = Attachment.fromJson({
        'type': 'url',
        'url': 'https://example.com',
        'label': 'Example',
      });
      expect(a, isA<UrlAttachment>());
      expect((a as UrlAttachment).url, 'https://example.com');
      expect(a.label, 'Example');
    });

    test('parses a geo_location attachment', () {
      final a = Attachment.fromJson({
        'type': 'geo_location',
        'latitude': 50.85,
        'longitude': 4.35,
      }) as GeoLocationAttachment;
      expect(a.latitude, closeTo(50.85, 1e-9));
      expect(a.longitude, closeTo(4.35, 1e-9));
      expect(a.label, isNull);
    });

    test('parses a time_trigger attachment', () {
      final a = Attachment.fromJson({
        'type': 'time_trigger',
        'triggerAt': '2026-05-26T09:00:00.000Z',
      }) as TimeTriggerAttachment;
      expect(a.triggerAt, equals(DateTime.utc(2026, 5, 26, 9)));
    });

    test('rejects unknown attachment type', () {
      expect(
        () => Attachment.fromJson({'type': 'meme'}),
        throwsFormatException,
      );
    });

    test('all variants roundtrip through json', () {
      final variants = <Attachment>[
        const UrlAttachment(url: 'https://example.com', label: 'Example'),
        const GeoLocationAttachment(latitude: 50.85, longitude: 4.35),
        TimeTriggerAttachment(
          triggerAt: DateTime.utc(2026, 5, 26, 9),
          label: 'Reminder',
        ),
      ];
      for (final original in variants) {
        final round = Attachment.fromJson(original.toJson());
        expect(round, equals(original));
      }
    });
  });
}
