import 'package:equatable/equatable.dart';

import 'filter.dart';

enum ExplorerDisplayMode {
  treeList('tree_list'),
  graph('graph');

  const ExplorerDisplayMode(this.jsonValue);
  final String jsonValue;

  static ExplorerDisplayMode fromJsonValue(String raw) =>
      ExplorerDisplayMode.values.firstWhere(
        (v) => v.jsonValue == raw,
        orElse: () => ExplorerDisplayMode.treeList,
      );
}

enum ExplorerGraphFlow {
  leavesToRoot('leaves_to_root'),
  rootToLeaves('root_to_leaves');

  const ExplorerGraphFlow(this.jsonValue);
  final String jsonValue;

  static ExplorerGraphFlow fromJsonValue(String raw) =>
      ExplorerGraphFlow.values.firstWhere(
        (v) => v.jsonValue == raw,
        orElse: () => ExplorerGraphFlow.leavesToRoot,
      );
}

class ExplorerViewSettings extends Equatable {
  const ExplorerViewSettings({
    this.displayMode = ExplorerDisplayMode.treeList,
    this.graphFlow = ExplorerGraphFlow.leavesToRoot,
    this.centerGraphParents = true,
  });

  final ExplorerDisplayMode displayMode;
  final ExplorerGraphFlow graphFlow;
  final bool centerGraphParents;

  ExplorerViewSettings copyWith({
    ExplorerDisplayMode? displayMode,
    ExplorerGraphFlow? graphFlow,
    bool? centerGraphParents,
  }) {
    return ExplorerViewSettings(
      displayMode: displayMode ?? this.displayMode,
      graphFlow: graphFlow ?? this.graphFlow,
      centerGraphParents: centerGraphParents ?? this.centerGraphParents,
    );
  }

  Map<String, dynamic> toJson() => {
    if (displayMode != ExplorerDisplayMode.treeList)
      'displayMode': displayMode.jsonValue,
    if (graphFlow != ExplorerGraphFlow.leavesToRoot)
      'graphFlow': graphFlow.jsonValue,
    if (!centerGraphParents) 'centerGraphParents': centerGraphParents,
  };

  factory ExplorerViewSettings.fromJson(Map<String, dynamic> json) {
    return ExplorerViewSettings(
      displayMode: ExplorerDisplayMode.fromJsonValue(
        (json['displayMode'] as String?) ??
            ExplorerDisplayMode.treeList.jsonValue,
      ),
      graphFlow: ExplorerGraphFlow.fromJsonValue(
        (json['graphFlow'] as String?) ??
            ExplorerGraphFlow.leavesToRoot.jsonValue,
      ),
      centerGraphParents: (json['centerGraphParents'] as bool?) ?? true,
    );
  }

  @override
  List<Object?> get props => [displayMode, graphFlow, centerGraphParents];
}

/// One tile on the dashboard. Tapping the tile opens a view pre-filtered by
/// [filter] and configured by [viewSettings].
class FilterPreset extends Equatable {
  const FilterPreset({
    required this.id,
    required this.title,
    required this.filter,
    this.viewSettings = const ExplorerViewSettings(),
    this.iconName,
    this.ordering,
  });

  final String id;
  final String title;
  final Filter filter;
  final ExplorerViewSettings viewSettings;

  /// Optional Material icon name shown on the tile face.
  final String? iconName;

  /// Sort order of tiles in the dashboard.
  final int? ordering;

  FilterPreset copyWith({
    String? title,
    Filter? filter,
    ExplorerViewSettings? viewSettings,
    String? iconName,
    int? ordering,
    bool clearOrdering = false,
  }) {
    return FilterPreset(
      id: id,
      title: title ?? this.title,
      filter: filter ?? this.filter,
      viewSettings: viewSettings ?? this.viewSettings,
      iconName: iconName ?? this.iconName,
      ordering: clearOrdering ? null : (ordering ?? this.ordering),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'filter': filter.toJson(),
    if (viewSettings != const ExplorerViewSettings())
      'viewSettings': viewSettings.toJson(),
    if (iconName != null) 'iconName': iconName,
    if (ordering != null) 'ordering': ordering,
  };

  factory FilterPreset.fromJson(Map<String, dynamic> json) {
    return FilterPreset(
      id: json['id'] as String,
      title: json['title'] as String,
      filter: Filter.fromJson(json['filter'] as Map<String, dynamic>),
      viewSettings: json['viewSettings'] == null
          ? const ExplorerViewSettings()
          : ExplorerViewSettings.fromJson(
              json['viewSettings'] as Map<String, dynamic>,
            ),
      iconName: json['iconName'] as String?,
      ordering: json['ordering'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    filter,
    viewSettings,
    iconName,
    ordering,
  ];
}
