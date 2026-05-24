import 'package:equatable/equatable.dart';

import 'edge.dart';
import 'filter_preset.dart';
import 'node.dart';
import 'node_relationship.dart';
import 'settings.dart';

/// Current on-disk schema version. Pre-release: no legacy support is
/// maintained — bumping this is fine, files written by older versions of
/// the app are intentionally not migrated.
const int kCurrentSchemaVersion = 1;

/// Root document for the Lakshya graph. The full graph (every node, every
/// structural edge, every importance/alternative relationship, every
/// dashboard filter preset, plus global settings) is persisted as a single
/// JSON document.
class LakshyaGraph extends Equatable {
  const LakshyaGraph({
    required this.nodes,
    required this.edges,
    this.relationships = const [],
    this.filterPresets = const [],
    this.settings,
    this.schemaVersion = kCurrentSchemaVersion,
  });

  /// An empty graph at the current schema version.
  const LakshyaGraph.empty()
      : nodes = const [],
        edges = const [],
        relationships = const [],
        filterPresets = const [],
        settings = null,
        schemaVersion = kCurrentSchemaVersion;

  final List<Node> nodes;
  final List<Edge> edges;
  final List<NodeRelationship> relationships;
  final List<FilterPreset> filterPresets;
  final Settings? settings;
  final int schemaVersion;

  LakshyaGraph copyWith({
    List<Node>? nodes,
    List<Edge>? edges,
    List<NodeRelationship>? relationships,
    List<FilterPreset>? filterPresets,
    Settings? settings,
    bool clearSettings = false,
  }) {
    return LakshyaGraph(
      schemaVersion: schemaVersion,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      relationships: relationships ?? this.relationships,
      filterPresets: filterPresets ?? this.filterPresets,
      settings: clearSettings ? null : (settings ?? this.settings),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        if (relationships.isNotEmpty)
          'relationships': relationships.map((r) => r.toJson()).toList(),
        if (filterPresets.isNotEmpty)
          'filterPresets': filterPresets.map((p) => p.toJson()).toList(),
        if (settings != null) 'settings': settings!.toJson(),
      };

  factory LakshyaGraph.fromJson(Map<String, dynamic> json) {
    final relationshipsRaw = json['relationships'] as List?;
    final presetsRaw = json['filterPresets'] as List?;
    final settingsRaw = json['settings'] as Map<String, dynamic>?;
    return LakshyaGraph(
      schemaVersion:
          (json['schemaVersion'] as int?) ?? kCurrentSchemaVersion,
      nodes: (json['nodes'] as List)
          .cast<Map<String, dynamic>>()
          .map(Node.fromJson)
          .toList(),
      edges: (json['edges'] as List)
          .cast<Map<String, dynamic>>()
          .map(Edge.fromJson)
          .toList(),
      relationships: relationshipsRaw == null
          ? const []
          : relationshipsRaw
              .cast<Map<String, dynamic>>()
              .map(NodeRelationship.fromJson)
              .toList(),
      filterPresets: presetsRaw == null
          ? const []
          : presetsRaw
              .cast<Map<String, dynamic>>()
              .map(FilterPreset.fromJson)
              .toList(),
      settings: settingsRaw == null ? null : Settings.fromJson(settingsRaw),
    );
  }

  @override
  List<Object?> get props => [
        schemaVersion,
        nodes,
        edges,
        relationships,
        filterPresets,
        settings,
      ];
}
