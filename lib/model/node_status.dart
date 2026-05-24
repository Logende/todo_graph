import 'package:equatable/equatable.dart';

/// Discriminator for the [NodeStatus] sealed hierarchy.
///
/// The string values match `schema/lakshya.schema.json` exactly so the JSON on
/// disk stays stable when the schema is regenerated for documentation.
enum StatusType {
  alwaysOn('always_on'),
  oneTime('one_time'),
  nTimes('n_times'),
  periodic('periodic'),
  temporarilyActive('temporarily_active');

  const StatusType(this.jsonValue);

  final String jsonValue;

  static StatusType fromJsonValue(String raw) {
    return StatusType.values.firstWhere(
      (value) => value.jsonValue == raw,
      orElse: () => throw FormatException('Unknown StatusType: "$raw"'),
    );
  }
}

/// One node's completion state. Each subtype models a different kind of life
/// cycle; the graph engine, ordering, and reminder layer all dispatch on these
/// variants.
sealed class NodeStatus extends Equatable {
  const NodeStatus();

  StatusType get type;

  Map<String, dynamic> toJson();

  static NodeStatus fromJson(Map<String, dynamic> json) {
    final raw = json['type'] as String?;
    if (raw == null) {
      throw const FormatException('NodeStatus is missing "type" field');
    }
    final type = StatusType.fromJsonValue(raw);
    return switch (type) {
      StatusType.alwaysOn => const AlwaysOnStatus(),
      StatusType.oneTime => OneTimeStatus.fromJson(json),
      StatusType.nTimes => NTimesStatus.fromJson(json),
      StatusType.periodic => PeriodicStatus.fromJson(json),
      StatusType.temporarilyActive => TemporarilyActiveStatus.fromJson(json),
    };
  }
}

/// Background goal with no completion state. Used for top-level life areas
/// like "Health" or "Work".
final class AlwaysOnStatus extends NodeStatus {
  const AlwaysOnStatus();

  @override
  StatusType get type => StatusType.alwaysOn;

  @override
  Map<String, dynamic> toJson() => {'type': type.jsonValue};

  @override
  List<Object?> get props => const [];
}

/// Task that is completed exactly once and then permanently done.
final class OneTimeStatus extends NodeStatus {
  const OneTimeStatus({this.completedAt});

  /// Absent while the task is open; set on completion.
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  @override
  StatusType get type => StatusType.oneTime;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.jsonValue,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };

  factory OneTimeStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['completedAt'] as String?;
    return OneTimeStatus(
      completedAt: raw == null ? null : DateTime.parse(raw),
    );
  }

  @override
  List<Object?> get props => [completedAt];
}

/// Task that must be completed a fixed number of times.
final class NTimesStatus extends NodeStatus {
  const NTimesStatus({
    required this.targetCount,
    this.completedCount = 0,
    this.lastCompletedAt,
  })  : assert(targetCount >= 1, 'targetCount must be at least 1'),
        assert(completedCount >= 0, 'completedCount cannot be negative');

  final int targetCount;
  final int completedCount;
  final DateTime? lastCompletedAt;

  int get remainingCount =>
      (targetCount - completedCount).clamp(0, targetCount);

  bool get isExhausted => completedCount >= targetCount;

  @override
  StatusType get type => StatusType.nTimes;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.jsonValue,
        'targetCount': targetCount,
        'completedCount': completedCount,
        if (lastCompletedAt != null)
          'lastCompletedAt': lastCompletedAt!.toIso8601String(),
      };

  factory NTimesStatus.fromJson(Map<String, dynamic> json) {
    final lastRaw = json['lastCompletedAt'] as String?;
    return NTimesStatus(
      targetCount: json['targetCount'] as int,
      completedCount: (json['completedCount'] as int?) ?? 0,
      lastCompletedAt: lastRaw == null ? null : DateTime.parse(lastRaw),
    );
  }

  @override
  List<Object?> get props => [targetCount, completedCount, lastCompletedAt];
}

/// Task that re-opens a fixed number of days AFTER the previous completion.
/// Completing late pushes the next due date forward; the cadence is relative,
/// not absolute on a calendar.
final class PeriodicStatus extends NodeStatus {
  const PeriodicStatus({
    required this.intervalDaysSinceLastCompletion,
    this.lastCompletedAt,
  }) : assert(intervalDaysSinceLastCompletion >= 1,
            'interval must be at least 1 day');

  final int intervalDaysSinceLastCompletion;

  /// Absent if the task has never been completed (it is open immediately).
  final DateTime? lastCompletedAt;

  /// Next moment at which this task should re-open. `null` means "open now".
  DateTime? nextDueAt() {
    final completed = lastCompletedAt;
    if (completed == null) return null;
    return completed.add(Duration(days: intervalDaysSinceLastCompletion));
  }

  /// True if the task is currently actionable for the given clock reading.
  bool isOpenAt(DateTime now) {
    final next = nextDueAt();
    return next == null || !now.isBefore(next);
  }

  @override
  StatusType get type => StatusType.periodic;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.jsonValue,
        'intervalDaysSinceLastCompletion': intervalDaysSinceLastCompletion,
        if (lastCompletedAt != null)
          'lastCompletedAt': lastCompletedAt!.toIso8601String(),
      };

  factory PeriodicStatus.fromJson(Map<String, dynamic> json) {
    final lastRaw = json['lastCompletedAt'] as String?;
    return PeriodicStatus(
      intervalDaysSinceLastCompletion:
          json['intervalDaysSinceLastCompletion'] as int,
      lastCompletedAt: lastRaw == null ? null : DateTime.parse(lastRaw),
    );
  }

  @override
  List<Object?> get props =>
      [intervalDaysSinceLastCompletion, lastCompletedAt];
}

/// Task or goal that is only active during a bounded time window. Outside the
/// window it is inactive regardless of completion.
final class TemporarilyActiveStatus extends NodeStatus {
  const TemporarilyActiveStatus({
    required this.activeFrom,
    required this.activeUntil,
    this.completedAt,
  });

  final DateTime activeFrom;
  final DateTime activeUntil;
  final DateTime? completedAt;

  bool isActiveAt(DateTime now) =>
      !now.isBefore(activeFrom) && !now.isAfter(activeUntil);

  bool get isCompleted => completedAt != null;

  @override
  StatusType get type => StatusType.temporarilyActive;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.jsonValue,
        'activeFrom': activeFrom.toIso8601String(),
        'activeUntil': activeUntil.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };

  factory TemporarilyActiveStatus.fromJson(Map<String, dynamic> json) {
    final completedRaw = json['completedAt'] as String?;
    return TemporarilyActiveStatus(
      activeFrom: DateTime.parse(json['activeFrom'] as String),
      activeUntil: DateTime.parse(json['activeUntil'] as String),
      completedAt: completedRaw == null ? null : DateTime.parse(completedRaw),
    );
  }

  @override
  List<Object?> get props => [activeFrom, activeUntil, completedAt];
}
