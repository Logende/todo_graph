import 'package:equatable/equatable.dart';

/// Per-node override of the global notification defaults. Any unset field
/// falls back to the global [Settings].
class NodeNotificationSettings extends Equatable {
  const NodeNotificationSettings({
    this.deadlineLeadTimeHours,
    this.notifyOnPeriodicReopen,
  });

  final int? deadlineLeadTimeHours;
  final bool? notifyOnPeriodicReopen;

  Map<String, dynamic> toJson() => {
        if (deadlineLeadTimeHours != null)
          'deadlineLeadTimeHours': deadlineLeadTimeHours,
        if (notifyOnPeriodicReopen != null)
          'notifyOnPeriodicReopen': notifyOnPeriodicReopen,
      };

  factory NodeNotificationSettings.fromJson(Map<String, dynamic> json) {
    return NodeNotificationSettings(
      deadlineLeadTimeHours: json['deadlineLeadTimeHours'] as int?,
      notifyOnPeriodicReopen: json['notifyOnPeriodicReopen'] as bool?,
    );
  }

  @override
  List<Object?> get props =>
      [deadlineLeadTimeHours, notifyOnPeriodicReopen];
}
