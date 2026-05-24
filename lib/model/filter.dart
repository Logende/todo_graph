import 'package:equatable/equatable.dart';

import 'contribution.dart';

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
    this.onlyOngoing = false,
    this.onlyLeaves = false,
    this.freeText,
  });

  /// Keep only nodes that are descendants of at least one of these goals.
  /// Empty means "no ancestor restriction".
  final List<String> ancestorGoalIds;

  /// Restrict to incoming edges of this contribution kind when computing
  /// descendants. [FilterContribution.any] keeps both mandatory and helpful.
  final FilterContribution contribution;

  /// Restrict to nodes whose completion aspect's `kind` is one of these.
  /// The special value `"none"` matches background goals (no completion).
  /// Empty list means "any completion kind".
  final List<String> completionKinds;

  /// Restrict to nodes whose activation window kind is one of these
  /// (`"always_active"`, `"bounded"`). Empty list means "any activation".
  final List<String> activationKinds;

  /// Keep only currently-actionable nodes.
  final bool onlyOngoing;

  /// Keep only nodes that are leaves within the filtered subgraph.
  final bool onlyLeaves;

  /// Case-insensitive substring match against node title and description.
  final String? freeText;

  Filter copyWith({
    List<String>? ancestorGoalIds,
    FilterContribution? contribution,
    List<String>? completionKinds,
    List<String>? activationKinds,
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
      onlyOngoing: onlyOngoing ?? this.onlyOngoing,
      onlyLeaves: onlyLeaves ?? this.onlyLeaves,
      freeText: clearFreeText ? null : (freeText ?? this.freeText),
    );
  }

  Map<String, dynamic> toJson() => {
        if (ancestorGoalIds.isNotEmpty) 'ancestorGoalIds': ancestorGoalIds,
        if (contribution != FilterContribution.any)
          'contribution': contribution.toJsonValue(),
        if (completionKinds.isNotEmpty) 'completionKinds': completionKinds,
        if (activationKinds.isNotEmpty) 'activationKinds': activationKinds,
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
      completionKinds: completionRaw ?? const [],
      activationKinds: activationRaw ?? const [],
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
        onlyOngoing,
        onlyLeaves,
        freeText,
      ];
}
