import 'package:equatable/equatable.dart';

import 'contribution.dart';

/// Which completion kind to include in a filter. The [none] value matches
/// background goals that have no completion concept at all.
enum CompletionKindFilter {
  none('none', 'Background goal'),
  oneTime('one_time', 'One-time'),
  nTimes('n_times', 'N-times'),
  periodic('periodic', 'Periodic');

  const CompletionKindFilter(this.jsonValue, this.displayLabel);
  final String jsonValue;
  final String displayLabel;

  static CompletionKindFilter fromJsonValue(String raw) {
    return CompletionKindFilter.values.firstWhere(
      (v) => v.jsonValue == raw,
      orElse: () =>
          throw FormatException('Unknown CompletionKindFilter: "$raw"'),
    );
  }
}

/// Which activation kind to include in a filter.
enum ActivationKindFilter {
  alwaysActive('always_active', 'Always active'),
  bounded('bounded', 'Bounded window');

  const ActivationKindFilter(this.jsonValue, this.displayLabel);
  final String jsonValue;
  final String displayLabel;

  static ActivationKindFilter fromJsonValue(String raw) {
    return ActivationKindFilter.values.firstWhere(
      (v) => v.jsonValue == raw,
      orElse: () =>
          throw FormatException('Unknown ActivationKindFilter: "$raw"'),
    );
  }
}

/// Composable filter spec used by the graph view, the todo list view, and
/// dashboard tiles.
///
/// All fields are optional. A [Filter] with no fields set matches every node.
class Filter extends Equatable {
  const Filter({
    this.ancestorGoalIds = const [],
    this.contribution = FilterContribution.any,
    this.completionKinds = const [],
    this.activationKinds = const [],
    this.showTimewiseInactiveTasks = false,
    this.showCompletedTasks = true,
    this.onlyOngoing = false,
    this.onlyLeaves = false,
    this.freeText,
  });

  final List<String> ancestorGoalIds;

  final FilterContribution contribution;

  /// Restrict to nodes whose completion aspect matches one of these.
  /// Empty list means "any completion kind".
  final List<CompletionKindFilter> completionKinds;

  /// Restrict to nodes whose activation window matches one of these.
  /// Empty list means "any activation".
  final List<ActivationKindFilter> activationKinds;

  final bool showTimewiseInactiveTasks;
  final bool showCompletedTasks;
  final bool onlyOngoing;
  final bool onlyLeaves;
  final String? freeText;

  Filter copyWith({
    List<String>? ancestorGoalIds,
    FilterContribution? contribution,
    List<CompletionKindFilter>? completionKinds,
    List<ActivationKindFilter>? activationKinds,
    bool? showTimewiseInactiveTasks,
    bool? showCompletedTasks,
    bool? onlyOngoing,
    bool? onlyLeaves,
    String? freeText,
    bool clearFreeText = false,
  }) {
    return Filter(
      ancestorGoalIds: ancestorGoalIds ?? this.ancestorGoalIds,
      contribution: contribution ?? this.contribution,
      completionKinds: completionKinds ?? this.completionKinds,
      activationKinds: activationKinds ?? this.activationKinds,
      showTimewiseInactiveTasks:
          showTimewiseInactiveTasks ?? this.showTimewiseInactiveTasks,
      showCompletedTasks: showCompletedTasks ?? this.showCompletedTasks,
      onlyOngoing: onlyOngoing ?? this.onlyOngoing,
      onlyLeaves: onlyLeaves ?? this.onlyLeaves,
      freeText: clearFreeText ? null : (freeText ?? this.freeText),
    );
  }

  Map<String, dynamic> toJson() => {
        if (ancestorGoalIds.isNotEmpty) 'ancestorGoalIds': ancestorGoalIds,
        if (contribution != FilterContribution.any)
          'contribution': contribution.toJsonValue(),
        if (completionKinds.isNotEmpty)
          'completionKinds':
              completionKinds.map((k) => k.jsonValue).toList(),
        if (activationKinds.isNotEmpty)
          'activationKinds':
              activationKinds.map((k) => k.jsonValue).toList(),
        if (showTimewiseInactiveTasks)
          'showTimewiseInactiveTasks': showTimewiseInactiveTasks,
        if (!showCompletedTasks) 'showCompletedTasks': showCompletedTasks,
        if (onlyOngoing) 'onlyOngoing': onlyOngoing,
        if (onlyLeaves) 'onlyLeaves': onlyLeaves,
        if (freeText != null) 'freeText': freeText,
      };

  factory Filter.fromJson(Map<String, dynamic> json) {
    final ancestors = (json['ancestorGoalIds'] as List?)?.cast<String>();
    final completionRaw = (json['completionKinds'] as List?)?.cast<String>();
    final activationRaw = (json['activationKinds'] as List?)?.cast<String>();
    final contribRaw = json['contribution'] as String?;
    return Filter(
      ancestorGoalIds: ancestors ?? const [],
      contribution: contribRaw == null
          ? FilterContribution.any
          : FilterContribution.fromJsonValue(contribRaw),
      completionKinds: completionRaw
              ?.map(CompletionKindFilter.fromJsonValue)
              .toList() ??
          const [],
      activationKinds: activationRaw
              ?.map(ActivationKindFilter.fromJsonValue)
              .toList() ??
          const [],
      showTimewiseInactiveTasks:
          (json['showTimewiseInactiveTasks'] as bool?) ?? false,
      showCompletedTasks: (json['showCompletedTasks'] as bool?) ?? true,
      onlyOngoing: (json['onlyOngoing'] as bool?) ?? false,
      onlyLeaves: (json['onlyLeaves'] as bool?) ?? false,
      freeText: json['freeText'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        ancestorGoalIds,
        contribution,
        completionKinds,
        activationKinds,
        showTimewiseInactiveTasks,
        showCompletedTasks,
        onlyOngoing,
        onlyLeaves,
        freeText,
      ];
}
