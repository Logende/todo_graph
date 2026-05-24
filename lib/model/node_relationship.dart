import 'package:equatable/equatable.dart';

/// How two nodes relate beyond the parent/child goal hierarchy.
///
/// Directional kinds carry meaning in the order of their (fromNodeId,
/// toNodeId): `moreImportantThan(A, B)` means "A is more important than B".
/// Bidirectional kinds (currently only [alternativeTo]) are symmetric — the
/// stored direction is incidental and both endpoints see the same relation.
enum RelationshipKind {
  moreImportantThan(isBidirectional: false),
  lessImportantThan(isBidirectional: false),
  alternativeTo(isBidirectional: true);

  const RelationshipKind({required this.isBidirectional});

  final bool isBidirectional;

  String toJsonValue() => name;

  static RelationshipKind fromJsonValue(String raw) {
    return RelationshipKind.values.firstWhere(
      (value) => value.name == raw,
      orElse: () =>
          throw FormatException('Unknown RelationshipKind: "$raw"'),
    );
  }
}

/// A non-structural connection between two nodes. Used by the ordering layer
/// (importance overrides) and by completion cascading (alternatives close
/// together).
class NodeRelationship extends Equatable {
  const NodeRelationship({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.kind,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final RelationshipKind kind;

  /// True when this relationship places [a] strictly above [b] in ordering.
  /// Returns false for the symmetric `alternativeTo` and for the wrong
  /// direction of a directional kind.
  bool placesAboveB(String a, String b) {
    return switch (kind) {
      RelationshipKind.moreImportantThan =>
        fromNodeId == a && toNodeId == b,
      RelationshipKind.lessImportantThan =>
        fromNodeId == b && toNodeId == a,
      RelationshipKind.alternativeTo => false,
    };
  }

  /// True when this relationship connects [nodeId] to [otherId] as
  /// alternatives, regardless of stored direction.
  bool isAlternativeBetween(String nodeId, String otherId) {
    if (kind != RelationshipKind.alternativeTo) return false;
    return (fromNodeId == nodeId && toNodeId == otherId) ||
        (fromNodeId == otherId && toNodeId == nodeId);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromNodeId': fromNodeId,
        'toNodeId': toNodeId,
        'kind': kind.toJsonValue(),
      };

  factory NodeRelationship.fromJson(Map<String, dynamic> json) {
    return NodeRelationship(
      id: json['id'] as String,
      fromNodeId: json['fromNodeId'] as String,
      toNodeId: json['toNodeId'] as String,
      kind: RelationshipKind.fromJsonValue(json['kind'] as String),
    );
  }

  @override
  List<Object?> get props => [id, fromNodeId, toNodeId, kind];
}
