import 'package:equatable/equatable.dart';

/// When a node is "live" on the calendar.
///
/// Orthogonal to [Completion]: a node can be a one-shot task within a bounded
/// window, or a recurring task only during a season, etc. Outside the window
/// the node is inactive regardless of its completion state.
sealed class ActivationWindow extends Equatable {
  const ActivationWindow();

  String get kind;

  bool isActiveAt(DateTime now);

  Map<String, dynamic> toJson();

  static ActivationWindow fromJson(Map<String, dynamic> json) {
    final raw = json['kind'] as String?;
    if (raw == null) {
      throw const FormatException(
        'ActivationWindow is missing "kind" field',
      );
    }
    return switch (raw) {
      'always_active' => const AlwaysActive(),
      'bounded' => BoundedActive.fromJson(json),
      _ => throw FormatException('Unknown ActivationWindow kind: "$raw"'),
    };
  }
}

/// Always live. The default for goals and tasks without a time window.
final class AlwaysActive extends ActivationWindow {
  const AlwaysActive();

  @override
  String get kind => 'always_active';

  @override
  bool isActiveAt(DateTime now) => true;

  @override
  Map<String, dynamic> toJson() => {'kind': kind};

  @override
  List<Object?> get props => const [];
}

/// Live within a time window. Either or both bounds may be omitted:
///
/// * Only [activeFrom] set → active from that date onward (no end).
/// * Only [activeUntil] set → active until that date (already started).
/// * Both set → active within the closed interval `[activeFrom, activeUntil]`.
///
/// When both are present, [activeUntil] must not precede [activeFrom].
final class BoundedActive extends ActivationWindow {
  BoundedActive({this.activeFrom, this.activeUntil}) {
    if (activeFrom != null &&
        activeUntil != null &&
        activeUntil!.isBefore(activeFrom!)) {
      throw ArgumentError(
        'activeUntil ($activeUntil) must not be before activeFrom '
        '($activeFrom)',
      );
    }
  }

  final DateTime? activeFrom;
  final DateTime? activeUntil;

  @override
  String get kind => 'bounded';

  @override
  bool isActiveAt(DateTime now) {
    if (activeFrom != null && now.isBefore(activeFrom!)) return false;
    if (activeUntil != null && now.isAfter(activeUntil!)) return false;
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (activeFrom != null) 'activeFrom': activeFrom!.toIso8601String(),
        if (activeUntil != null) 'activeUntil': activeUntil!.toIso8601String(),
      };

  factory BoundedActive.fromJson(Map<String, dynamic> json) {
    final fromRaw = json['activeFrom'] as String?;
    final untilRaw = json['activeUntil'] as String?;
    try {
      return BoundedActive(
        activeFrom: fromRaw == null ? null : DateTime.parse(fromRaw),
        activeUntil: untilRaw == null ? null : DateTime.parse(untilRaw),
      );
    } on ArgumentError catch (e) {
      throw FormatException(e.message.toString());
    }
  }

  @override
  List<Object?> get props => [activeFrom, activeUntil];
}
