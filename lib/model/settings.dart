import 'package:equatable/equatable.dart';

import 'filter_preset.dart';

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
    this.tileViewSettings = const {},
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

  /// Per-dashboard-tile view settings (graph vs list, etc.) for the built-in
  /// "All" tile and the auto-generated top-level goal tiles, keyed by a stable
  /// tile id. Saved presets carry their own view settings inline instead.
  ///
  /// Read defensively: a missing key falls back to a default
  /// [ExplorerViewSettings], so new fields or absent entries never break.
  final Map<String, ExplorerViewSettings> tileViewSettings;

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
    Map<String, ExplorerViewSettings>? tileViewSettings,
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
      tileViewSettings: tileViewSettings ?? this.tileViewSettings,
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
    if (tileViewSettings.isNotEmpty)
      'tileViewSettings': {
        for (final entry in tileViewSettings.entries)
          entry.key: entry.value.toJson(),
      },
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
      tileViewSettings: _tileViewSettingsFromJson(json['tileViewSettings']),
    );
  }

  /// Parses the per-tile view settings map defensively: a missing map yields
  /// an empty map, and any malformed entry falls back to defaults rather than
  /// throwing.
  static Map<String, ExplorerViewSettings> _tileViewSettingsFromJson(
    Object? raw,
  ) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): entry.value is Map<String, dynamic>
            ? ExplorerViewSettings.fromJson(entry.value as Map<String, dynamic>)
            : const ExplorerViewSettings(),
    };
  }

  @override
  List<Object?> get props => [
    defaultDeadlineLeadTimeHours,
    notifyOnPeriodicReopenByDefault,
    rootNodeId,
    urgentWindowDays,
    collapsedNodeIds,
    tileViewSettings,
  ];
}
