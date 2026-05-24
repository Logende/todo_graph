import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/edge.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';

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
  double? priority,
  double? positiveImpact,
}) {
  return Node(
    id: id,
    title: title ?? id,
    description: description,
    status: status ?? NodeStatus.alwaysOnBackground,
    createdAt: createdAt ?? defaultCreatedAt,
    deadline: deadline,
    priority: priority,
    positiveImpact: positiveImpact,
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
