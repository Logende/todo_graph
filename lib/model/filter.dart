import 'package:equatable/equatable.dart';

import 'contribution.dart';
import 'node_status.dart';

/// Composable filter spec used by the graph view, the todo list view, and
/// dashboard tiles.
///
/// All fields are optional. A [Filter] with no fields set matches every node.
class Filter extends Equatable {
  const Filter({
    this.ancestorGoalIds = const [],
    this.contribution = FilterContribution.any,
    this.statusTypes = const [],
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

  /// Keep only nodes whose status type is one of these. Empty means "any".
  final List<StatusType> statusTypes;

  /// Keep only currently-actionable nodes.
  final bool onlyOngoing;

  /// Keep only nodes that are leaves within the filtered subgraph.
  final bool onlyLeaves;

  /// Case-insensitive substring match against node title and description.
  final String? freeText;

  Map<String, dynamic> toJson() => {
        if (ancestorGoalIds.isNotEmpty) 'ancestorGoalIds': ancestorGoalIds,
        if (contribution != FilterContribution.any)
          'contribution': contribution.toJsonValue(),
        if (statusTypes.isNotEmpty)
          'statusTypes': statusTypes.map((t) => t.jsonValue).toList(),
        if (onlyOngoing) 'onlyOngoing': onlyOngoing,
        if (onlyLeaves) 'onlyLeaves': onlyLeaves,
        if (freeText != null) 'freeText': freeText,
      };

  factory Filter.fromJson(Map<String, dynamic> json) {
    final ancestors = (json['ancestorGoalIds'] as List?)?.cast<String>();
    final statusRaw = (json['statusTypes'] as List?)?.cast<String>();
    final contribRaw = json['contribution'] as String?;
    return Filter(
      ancestorGoalIds: ancestors ?? const [],
      contribution: contribRaw == null
          ? FilterContribution.any
          : FilterContribution.fromJsonValue(contribRaw),
      statusTypes: statusRaw == null
          ? const []
          : statusRaw.map(StatusType.fromJsonValue).toList(),
      onlyOngoing: (json['onlyOngoing'] as bool?) ?? false,
      onlyLeaves: (json['onlyLeaves'] as bool?) ?? false,
      freeText: json['freeText'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        ancestorGoalIds,
        contribution,
        statusTypes,
        onlyOngoing,
        onlyLeaves,
        freeText,
      ];
}
