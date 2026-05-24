import 'package:equatable/equatable.dart';

import 'filter.dart';

/// One tile on the dashboard. Tapping the tile opens a view pre-filtered by
/// [filter].
class FilterPreset extends Equatable {
  const FilterPreset({
    required this.id,
    required this.title,
    required this.filter,
    this.iconName,
    this.ordering,
  });

  final String id;
  final String title;
  final Filter filter;

  /// Optional Material icon name shown on the tile face.
  final String? iconName;

  /// Sort order of tiles in the dashboard.
  final int? ordering;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filter': filter.toJson(),
        if (iconName != null) 'iconName': iconName,
        if (ordering != null) 'ordering': ordering,
      };

  factory FilterPreset.fromJson(Map<String, dynamic> json) {
    return FilterPreset(
      id: json['id'] as String,
      title: json['title'] as String,
      filter: Filter.fromJson(json['filter'] as Map<String, dynamic>),
      iconName: json['iconName'] as String?,
      ordering: json['ordering'] as int?,
    );
  }

  @override
  List<Object?> get props => [id, title, filter, iconName, ordering];
}
