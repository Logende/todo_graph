import 'package:equatable/equatable.dart';

import 'attachment.dart';
import 'node_notification_settings.dart';
import 'node_status.dart';

/// A single goal or task in the Lakshya graph.
///
/// Edges (parent links) live separately in [Edge]s on the graph document, so
/// nodes themselves carry only their own intrinsic state.
class Node extends Equatable {
  const Node({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.description,
    this.priority,
    this.positiveImpact,
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

  /// User-assigned priority score. Higher ranks earlier in the default order.
  final double? priority;

  /// User-assigned positive impact estimate, combined with [priority] when
  /// computing the default ordering.
  final double? positiveImpact;

  /// Hard deadline for this node. Drives deadline reminders.
  final DateTime? deadline;

  final List<Attachment> attachments;
  final NodeNotificationSettings? notificationOverride;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status.toJson(),
        'createdAt': createdAt.toIso8601String(),
        if (description != null) 'description': description,
        if (priority != null) 'priority': priority,
        if (positiveImpact != null) 'positiveImpact': positiveImpact,
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
    return Node(
      id: json['id'] as String,
      title: json['title'] as String,
      status: NodeStatus.fromJson(json['status'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String?,
      priority: (json['priority'] as num?)?.toDouble(),
      positiveImpact: (json['positiveImpact'] as num?)?.toDouble(),
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
        priority,
        positiveImpact,
        deadline,
        attachments,
        notificationOverride,
        updatedAt,
      ];
}
