import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/edge.dart';
import 'package:lakshya/model/filter_preset.dart';
import 'package:lakshya/model/impact.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_relationship.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/model/settings.dart';

/// Default `createdAt` used by [buildNode]. Centralised so tests can sort or
/// compare against a known reference without coupling to the wall clock.
final DateTime defaultCreatedAt = DateTime.utc(2026, 5, 24);

/// Builds a Node with sensible defaults for tests.
///
/// `title` defaults to `id` so assertions reading either field stay readable.
/// `status` defaults to a background goal — the most common shape in
/// fixtures. Override any field via the named parameters.
Node buildNode(
  String id, {
  String? title,
  String? description,
  NodeStatus? status,
  DateTime? createdAt,
  DateTime? deadline,
  Impact? impact,
}) {
  return Node(
    id: id,
    title: title ?? id,
    description: description,
    status: status ?? NodeStatus.alwaysOnBackground,
    createdAt: createdAt ?? defaultCreatedAt,
    deadline: deadline,
    impact: impact,
  );
}

/// Builds a LakshyaGraph with sensible defaults for tests. Every field is
/// optional and defaults to empty / null so only the relevant setup for
/// the test under consideration needs to be specified.
LakshyaGraph buildGraph({
  List<Node>? nodes,
  List<Edge>? edges,
  List<NodeRelationship>? relationships,
  List<FilterPreset>? filterPresets,
  Settings? settings,
}) {
  return LakshyaGraph(
    nodes: nodes ?? const [],
    edges: edges ?? const [],
    relationships: relationships ?? const [],
    filterPresets: filterPresets ?? const [],
    settings: settings,
  );
}

/// Builds an Edge with mandatory contribution by default.
Edge buildEdge(
  String id, {
  required String from,
  required String to,
  Contribution contribution = Contribution.mandatory,
}) {
  return Edge(
    id: id,
    childId: from,
    parentId: to,
    contribution: contribution,
  );
}
