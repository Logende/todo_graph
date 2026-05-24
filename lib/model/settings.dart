import 'package:equatable/equatable.dart';

/// Global, document-wide settings for a Lakshya graph.
class Settings extends Equatable {
  const Settings({
    this.defaultDeadlineLeadTimeHours,
    this.notifyOnPeriodicReopenByDefault,
    this.rootNodeId,
  });

  /// Default hours before a deadline at which a reminder fires. Nodes may
  /// override via `notificationOverride`.
  final int? defaultDeadlineLeadTimeHours;

  /// Whether a notification fires when a periodic task becomes open again,
  /// unless the node overrides it.
  final bool? notifyOnPeriodicReopenByDefault;

  /// ID of the "all goals achieved" top-level node. The graph engine treats
  /// this as the universal ancestor when computing descendant filters with no
  /// `ancestorGoalIds` set.
  final String? rootNodeId;

  Map<String, dynamic> toJson() => {
        if (defaultDeadlineLeadTimeHours != null)
          'defaultDeadlineLeadTimeHours': defaultDeadlineLeadTimeHours,
        if (notifyOnPeriodicReopenByDefault != null)
          'notifyOnPeriodicReopenByDefault': notifyOnPeriodicReopenByDefault,
        if (rootNodeId != null) 'rootNodeId': rootNodeId,
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      defaultDeadlineLeadTimeHours:
          json['defaultDeadlineLeadTimeHours'] as int?,
      notifyOnPeriodicReopenByDefault:
          json['notifyOnPeriodicReopenByDefault'] as bool?,
      rootNodeId: json['rootNodeId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        defaultDeadlineLeadTimeHours,
        notifyOnPeriodicReopenByDefault,
        rootNodeId,
      ];
}
