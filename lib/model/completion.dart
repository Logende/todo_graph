import 'package:equatable/equatable.dart';

/// What it means for this node to be "done".
///
/// Orthogonal to [ActivationWindow] — a node that is only active during a
/// bounded window can still need to be completed N times within that window,
/// or recur every few days inside it.
///
/// A node with no [Completion] is a background goal (no completion concept);
/// always considered ongoing whenever its activation window is open.
sealed class Completion extends Equatable {
  const Completion();

  String get kind;

  bool isOngoingAt(DateTime now);

  Completion markCompletedAt(DateTime now);

  Map<String, dynamic> toJson();

  static Completion fromJson(Map<String, dynamic> json) {
    final raw = json['kind'] as String?;
    if (raw == null) {
      throw const FormatException('Completion is missing "kind" field');
    }
    return switch (raw) {
      'one_time' => OneTimeCompletion.fromJson(json),
      'n_times' => NTimesCompletion.fromJson(json),
      'periodic' => PeriodicCompletion.fromJson(json),
      _ => throw FormatException('Unknown Completion kind: "$raw"'),
    };
  }
}

/// Done exactly once.
final class OneTimeCompletion extends Completion {
  const OneTimeCompletion({this.completedAt});

  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  @override
  String get kind => 'one_time';

  @override
  bool isOngoingAt(DateTime now) => !isCompleted;

  @override
  Completion markCompletedAt(DateTime now) =>
      OneTimeCompletion(completedAt: now);

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };

  factory OneTimeCompletion.fromJson(Map<String, dynamic> json) {
    final raw = json['completedAt'] as String?;
    return OneTimeCompletion(
      completedAt: raw == null ? null : DateTime.parse(raw),
    );
  }

  @override
  List<Object?> get props => [completedAt];
}

/// Must be completed a fixed number of times.
final class NTimesCompletion extends Completion {
  const NTimesCompletion({
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
  String get kind => 'n_times';

  @override
  bool isOngoingAt(DateTime now) => !isExhausted;

  @override
  Completion markCompletedAt(DateTime now) => NTimesCompletion(
        targetCount: targetCount,
        completedCount: (completedCount + 1).clamp(0, targetCount),
        lastCompletedAt: now,
      );

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'targetCount': targetCount,
        'completedCount': completedCount,
        if (lastCompletedAt != null)
          'lastCompletedAt': lastCompletedAt!.toIso8601String(),
      };

  factory NTimesCompletion.fromJson(Map<String, dynamic> json) {
    final lastRaw = json['lastCompletedAt'] as String?;
    return NTimesCompletion(
      targetCount: json['targetCount'] as int,
      completedCount: (json['completedCount'] as int?) ?? 0,
      lastCompletedAt: lastRaw == null ? null : DateTime.parse(lastRaw),
    );
  }

  @override
  List<Object?> get props => [targetCount, completedCount, lastCompletedAt];
}

/// Re-opens a fixed number of days AFTER each completion. The cadence is
/// relative to actual completion timestamps, not a calendar.
final class PeriodicCompletion extends Completion {
  const PeriodicCompletion({
    required this.intervalDaysSinceLastCompletion,
    this.lastCompletedAt,
  }) : assert(intervalDaysSinceLastCompletion >= 1,
            'interval must be at least 1 day');

  final int intervalDaysSinceLastCompletion;
  final DateTime? lastCompletedAt;

  DateTime? nextDueAt() {
    final completed = lastCompletedAt;
    if (completed == null) return null;
    return completed.add(Duration(days: intervalDaysSinceLastCompletion));
  }

  bool isOpenAt(DateTime now) {
    final next = nextDueAt();
    return next == null || !now.isBefore(next);
  }

  @override
  String get kind => 'periodic';

  @override
  bool isOngoingAt(DateTime now) => isOpenAt(now);

  @override
  Completion markCompletedAt(DateTime now) => PeriodicCompletion(
        intervalDaysSinceLastCompletion: intervalDaysSinceLastCompletion,
        lastCompletedAt: now,
      );

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'intervalDaysSinceLastCompletion': intervalDaysSinceLastCompletion,
        if (lastCompletedAt != null)
          'lastCompletedAt': lastCompletedAt!.toIso8601String(),
      };

  factory PeriodicCompletion.fromJson(Map<String, dynamic> json) {
    final lastRaw = json['lastCompletedAt'] as String?;
    return PeriodicCompletion(
      intervalDaysSinceLastCompletion:
          json['intervalDaysSinceLastCompletion'] as int,
      lastCompletedAt: lastRaw == null ? null : DateTime.parse(lastRaw),
    );
  }

  @override
  List<Object?> get props =>
      [intervalDaysSinceLastCompletion, lastCompletedAt];
}
