import 'package:equatable/equatable.dart';

import 'attachment.dart';
import 'impact.dart';
import 'node_notification_settings.dart';
import 'node_status.dart';

/// A single goal or task in the Lakshya graph.
///
/// Structural parent edges live on the graph document (see `Edge`), as do
/// importance/alternative relationships (`NodeRelationship`). A node itself
/// carries only its own intrinsic state.
class Node extends Equatable {
  const Node({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.description,
    this.impact,
    this.deadline,
    this.attachments = const [],
    this.notificationOverride,
    this.updatedAt,
  });

  final String id;
  final String title;
  final NodeStatus status;
  final DateTime createdAt;

  final String? description;

  /// Fixed five-level user estimate of how impactful completing this node is.
  /// Used by the default ordering when sorting non-urgent tasks. Relative
  /// importance between specific nodes is expressed separately via
  /// `NodeRelationship`.
  final Impact? impact;

  /// Hard deadline for this node. Drives deadline reminders and the
  /// "due-soon" tier of the default ordering.
  final DateTime? deadline;

  final List<Attachment> attachments;
  final NodeNotificationSettings? notificationOverride;
  final DateTime? updatedAt;

  Node copyWith({
    String? title,
    NodeStatus? status,
    DateTime? createdAt,
    String? description,
    Impact? impact,
    DateTime? deadline,
    List<Attachment>? attachments,
    NodeNotificationSettings? notificationOverride,
    DateTime? updatedAt,
    bool clearImpact = false,
    bool clearDeadline = false,
    bool clearDescription = false,
    bool clearNotificationOverride = false,
  }) {
    return Node(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      description: clearDescription ? null : (description ?? this.description),
      impact: clearImpact ? null : (impact ?? this.impact),
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      attachments: attachments ?? this.attachments,
      notificationOverride: clearNotificationOverride
          ? null
          : (notificationOverride ?? this.notificationOverride),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status.toJson(),
        'createdAt': createdAt.toIso8601String(),
        if (description != null) 'description': description,
        if (impact != null) 'impact': impact!.toJsonValue(),
        if (deadline != null) 'deadline': deadline!.toIso8601String(),
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
        if (notificationOverride != null)
          'notificationOverride': notificationOverride!.toJson(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory Node.fromJson(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'] as List?;
    final deadlineRaw = json['deadline'] as String?;
    final updatedRaw = json['updatedAt'] as String?;
    final overrideRaw = json['notificationOverride'] as Map<String, dynamic>?;
    final impactRaw = json['impact'] as String?;
    return Node(
      id: json['id'] as String,
      title: json['title'] as String,
      status: NodeStatus.fromJson(json['status'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String?,
      impact: impactRaw == null ? null : Impact.fromJsonValue(impactRaw),
      deadline: deadlineRaw == null ? null : DateTime.parse(deadlineRaw),
      attachments: attachmentsRaw == null
          ? const []
          : attachmentsRaw
              .cast<Map<String, dynamic>>()
              .map(Attachment.fromJson)
              .toList(),
      notificationOverride: overrideRaw == null
          ? null
          : NodeNotificationSettings.fromJson(overrideRaw),
      updatedAt: updatedRaw == null ? null : DateTime.parse(updatedRaw),
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        status,
        createdAt,
        description,
        impact,
        deadline,
        attachments,
        notificationOverride,
        updatedAt,
      ];
}
