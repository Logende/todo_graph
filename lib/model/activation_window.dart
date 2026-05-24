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

/// Live only between [activeFrom] and [activeUntil] inclusive.
final class BoundedActive extends ActivationWindow {
  BoundedActive({
    required this.activeFrom,
    required this.activeUntil,
  }) {
    if (activeUntil.isBefore(activeFrom)) {
      throw ArgumentError(
        'activeUntil ($activeUntil) must not be before activeFrom '
        '($activeFrom)',
      );
    }
  }

  final DateTime activeFrom;
  final DateTime activeUntil;

  @override
  String get kind => 'bounded';

  @override
  bool isActiveAt(DateTime now) =>
      !now.isBefore(activeFrom) && !now.isAfter(activeUntil);

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'activeFrom': activeFrom.toIso8601String(),
        'activeUntil': activeUntil.toIso8601String(),
      };

  factory BoundedActive.fromJson(Map<String, dynamic> json) {
    final activeFrom = DateTime.parse(json['activeFrom'] as String);
    final activeUntil = DateTime.parse(json['activeUntil'] as String);
    try {
      return BoundedActive(activeFrom: activeFrom, activeUntil: activeUntil);
    } on ArgumentError catch (e) {
      throw FormatException(e.message.toString());
    }
  }

  @override
  List<Object?> get props => [activeFrom, activeUntil];
}
