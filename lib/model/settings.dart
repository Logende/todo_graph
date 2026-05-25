import 'package:equatable/equatable.dart';

/// Default urgency window in days. Tasks with a deadline this many days away
/// or sooner are surfaced as urgent by the ordering layer.
const int kDefaultUrgentWindowDays = 3;

/// Global, document-wide settings for a Lakshya graph.
class Settings extends Equatable {
  const Settings({
    this.defaultDeadlineLeadTimeHours,
    this.notifyOnPeriodicReopenByDefault,
    this.rootNodeId,
    this.urgentWindowDays,
    this.collapsedNodeIds = const [],
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

  /// Tasks with a deadline this many days or fewer away get top-of-list
  /// "urgent" treatment in the default ordering. Unset means use
  /// [kDefaultUrgentWindowDays].
  final int? urgentWindowDays;

  /// Persisted collapsed state for the hierarchical todo list view.
  final List<String> collapsedNodeIds;

  int get effectiveUrgentWindowDays =>
      urgentWindowDays ?? kDefaultUrgentWindowDays;

  Settings copyWith({
    int? defaultDeadlineLeadTimeHours,
    bool clearDefaultDeadlineLeadTimeHours = false,
    bool? notifyOnPeriodicReopenByDefault,
    bool clearNotifyOnPeriodicReopenByDefault = false,
    String? rootNodeId,
    int? urgentWindowDays,
    bool clearUrgentWindowDays = false,
    List<String>? collapsedNodeIds,
  }) {
    return Settings(
      defaultDeadlineLeadTimeHours: clearDefaultDeadlineLeadTimeHours
          ? null
          : (defaultDeadlineLeadTimeHours ?? this.defaultDeadlineLeadTimeHours),
      notifyOnPeriodicReopenByDefault: clearNotifyOnPeriodicReopenByDefault
          ? null
          : (notifyOnPeriodicReopenByDefault ??
              this.notifyOnPeriodicReopenByDefault),
      rootNodeId: rootNodeId ?? this.rootNodeId,
      urgentWindowDays: clearUrgentWindowDays
          ? null
          : (urgentWindowDays ?? this.urgentWindowDays),
      collapsedNodeIds: collapsedNodeIds ?? this.collapsedNodeIds,
    );
  }

  Map<String, dynamic> toJson() => {
        if (defaultDeadlineLeadTimeHours != null)
          'defaultDeadlineLeadTimeHours': defaultDeadlineLeadTimeHours,
        if (notifyOnPeriodicReopenByDefault != null)
          'notifyOnPeriodicReopenByDefault': notifyOnPeriodicReopenByDefault,
        if (rootNodeId != null) 'rootNodeId': rootNodeId,
        if (urgentWindowDays != null) 'urgentWindowDays': urgentWindowDays,
        if (collapsedNodeIds.isNotEmpty) 'collapsedNodeIds': collapsedNodeIds,
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      defaultDeadlineLeadTimeHours:
          json['defaultDeadlineLeadTimeHours'] as int?,
      notifyOnPeriodicReopenByDefault:
          json['notifyOnPeriodicReopenByDefault'] as bool?,
      rootNodeId: json['rootNodeId'] as String?,
      urgentWindowDays: json['urgentWindowDays'] as int?,
      collapsedNodeIds:
          (json['collapsedNodeIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  List<Object?> get props => [
        defaultDeadlineLeadTimeHours,
        notifyOnPeriodicReopenByDefault,
        rootNodeId,
        urgentWindowDays,
        collapsedNodeIds,
      ];
}
