import 'package:equatable/equatable.dart';

enum AttachmentType {
  url('url'),
  geoLocation('geo_location'),
  timeTrigger('time_trigger');

  const AttachmentType(this.jsonValue);

  final String jsonValue;

  static AttachmentType fromJsonValue(String raw) {
    return AttachmentType.values.firstWhere(
      (value) => value.jsonValue == raw,
      orElse: () => throw FormatException('Unknown AttachmentType: "$raw"'),
    );
  }
}

/// Extra metadata attached to a node: a URL, a geo location, or a one-shot
/// time-based reminder.
sealed class Attachment extends Equatable {
  const Attachment({this.label});

  /// Optional human-readable label shown alongside the attachment.
  final String? label;

  AttachmentType get type;

  Map<String, dynamic> toJson();

  static Attachment fromJson(Map<String, dynamic> json) {
    final raw = json['type'] as String?;
    if (raw == null) {
      throw const FormatException('Attachment is missing "type" field');
    }
    final type = AttachmentType.fromJsonValue(raw);
    return switch (type) {
      AttachmentType.url => UrlAttachment.fromJson(json),
      AttachmentType.geoLocation => GeoLocationAttachment.fromJson(json),
      AttachmentType.timeTrigger => TimeTriggerAttachment.fromJson(json),
    };
  }
}

final class UrlAttachment extends Attachment {
  const UrlAttachment({required this.url, super.label});

  final String url;

  @override
  AttachmentType get type => AttachmentType.url;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.jsonValue,
        'url': url,
        if (label != null) 'label': label,
      };

  factory UrlAttachment.fromJson(Map<String, dynamic> json) {
    return UrlAttachment(
      url: json['url'] as String,
      label: json['label'] as String?,
    );
  }

  @override
  List<Object?> get props => [url, label];
}

final class GeoLocationAttachment extends Attachment {
  const GeoLocationAttachment({
    required this.latitude,
    required this.longitude,
    super.label,
  });

  final double latitude;
  final double longitude;

  @override
  AttachmentType get type => AttachmentType.geoLocation;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.jsonValue,
        'latitude': latitude,
        'longitude': longitude,
        if (label != null) 'label': label,
      };

  factory GeoLocationAttachment.fromJson(Map<String, dynamic> json) {
    return GeoLocationAttachment(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      label: json['label'] as String?,
    );
  }

  @override
  List<Object?> get props => [latitude, longitude, label];
}

/// Fires a reminder at the given moment, independent of the node's deadline.
final class TimeTriggerAttachment extends Attachment {
  const TimeTriggerAttachment({required this.triggerAt, super.label});

  final DateTime triggerAt;

  @override
  AttachmentType get type => AttachmentType.timeTrigger;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.jsonValue,
        'triggerAt': triggerAt.toIso8601String(),
        if (label != null) 'label': label,
      };

  factory TimeTriggerAttachment.fromJson(Map<String, dynamic> json) {
    return TimeTriggerAttachment(
      triggerAt: DateTime.parse(json['triggerAt'] as String),
      label: json['label'] as String?,
    );
  }

  @override
  List<Object?> get props => [triggerAt, label];
}
