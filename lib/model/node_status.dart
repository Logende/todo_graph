import 'package:equatable/equatable.dart';

import 'activation_window.dart';
import 'completion.dart';

/// The full lifecycle state of a node, composed of two orthogonal axes:
/// when the node is live ([activation]) and what it means to be done
/// ([completion]).
///
/// Either axis can be the "background" choice — `AlwaysActive` always-on,
/// and `completion: null` for a goal that has no completion concept (e.g.
/// "Health"). Combining a bounded window with an N-times completion is the
/// driving use case for this composite (e.g. "in May, do 3 chess puzzles").
class NodeStatus extends Equatable {
  const NodeStatus({
    this.activation = const AlwaysActive(),
    this.completion,
  });

  /// Background goal with no completion concept. The most common status for
  /// top-level life areas.
  static const NodeStatus alwaysOnBackground =
      NodeStatus(activation: AlwaysActive());

  /// Convenience: always active, one-shot completion.
  NodeStatus.oneTime({DateTime? completedAt})
      : activation = const AlwaysActive(),
        completion = OneTimeCompletion(completedAt: completedAt);

  /// Convenience: always active, N-times completion.
  NodeStatus.nTimes({
    required int targetCount,
    int completedCount = 0,
    DateTime? lastCompletedAt,
  })  : activation = const AlwaysActive(),
        completion = NTimesCompletion(
          targetCount: targetCount,
          completedCount: completedCount,
          lastCompletedAt: lastCompletedAt,
        );

  /// Convenience: always active, periodic completion with a fixed cool-down
  /// in days relative to the previous completion.
  NodeStatus.periodic({
    required int intervalDaysSinceLastCompletion,
    DateTime? lastCompletedAt,
  })  : activation = const AlwaysActive(),
        completion = PeriodicCompletion(
          intervalDaysSinceLastCompletion: intervalDaysSinceLastCompletion,
          lastCompletedAt: lastCompletedAt,
        );

  /// Convenience: bounded activation window with an optional completion
  /// aspect inside the window.
  NodeStatus.bounded({
    required DateTime activeFrom,
    required DateTime activeUntil,
    this.completion,
  }) : activation = BoundedActive(
          activeFrom: activeFrom,
          activeUntil: activeUntil,
        );

  final ActivationWindow activation;

  /// `null` means this node is a background goal with no completion concept.
  final Completion? completion;

  /// A node is ongoing if its window is open AND (it has no completion
  /// concept OR its completion is not yet satisfied).
  bool isOngoingAt(DateTime now) {
    if (!activation.isActiveAt(now)) return false;
    final c = completion;
    return c == null || c.isOngoingAt(now);
  }

  /// Applies a completion event. Background goals (no completion) are
  /// unchanged. The activation window is preserved.
  NodeStatus markCompletedAt(DateTime now) {
    final c = completion;
    if (c == null) return this;
    return NodeStatus(
      activation: activation,
      completion: c.markCompletedAt(now),
    );
  }

  /// Re-opens a previously completed task. Background goals (no completion)
  /// are unchanged.
  NodeStatus markIncomplete() {
    final c = completion;
    if (c == null) return this;
    return NodeStatus(
      activation: activation,
      completion: c.markIncomplete(),
    );
  }

  NodeStatus copyWith({
    ActivationWindow? activation,
    Completion? completion,
    bool clearCompletion = false,
  }) {
    return NodeStatus(
      activation: activation ?? this.activation,
      completion: clearCompletion ? null : (completion ?? this.completion),
    );
  }

  Map<String, dynamic> toJson() => {
        'activation': activation.toJson(),
        if (completion != null) 'completion': completion!.toJson(),
      };

  factory NodeStatus.fromJson(Map<String, dynamic> json) {
    final activationRaw = json['activation'] as Map<String, dynamic>?;
    final completionRaw = json['completion'] as Map<String, dynamic>?;
    if (activationRaw == null) {
      throw const FormatException(
        'NodeStatus is missing the required "activation" field',
      );
    }
    return NodeStatus(
      activation: ActivationWindow.fromJson(activationRaw),
      completion:
          completionRaw == null ? null : Completion.fromJson(completionRaw),
    );
  }

  @override
  List<Object?> get props => [activation, completion];
}
