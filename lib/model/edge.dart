import 'package:equatable/equatable.dart';

import 'contribution.dart';

/// Directed contribution from a child node to a parent goal.
///
/// A node can have many parents — the same `childId` appears in multiple
/// edges. Each edge carries its own [contribution] kind so the same task can
/// be mandatory for one parent and merely helpful for another.
class Edge extends Equatable {
  const Edge({
    required this.id,
    required this.childId,
    required this.parentId,
    required this.contribution,
  });

  final String id;

  /// The lower-level node that contributes upward.
  final String childId;

  /// The higher-level goal being contributed to.
  final String parentId;

  final Contribution contribution;

  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'parentId': parentId,
        'contribution': contribution.toJsonValue(),
      };

  factory Edge.fromJson(Map<String, dynamic> json) {
    return Edge(
      id: json['id'] as String,
      childId: json['childId'] as String,
      parentId: json['parentId'] as String,
      contribution:
          Contribution.fromJsonValue(json['contribution'] as String),
    );
  }

  @override
  List<Object?> get props => [id, childId, parentId, contribution];
}
