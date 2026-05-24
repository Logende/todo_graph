import 'package:equatable/equatable.dart';

/// Hard manual override declaring that one node ranks above another,
/// regardless of their priority/impact scores. Used by the default ordering
/// to break ties in a way the user has explicitly pinned.
class PriorityPin extends Equatable {
  const PriorityPin({required this.higherId, required this.lowerId});

  final String higherId;
  final String lowerId;

  Map<String, dynamic> toJson() => {
        'higherId': higherId,
        'lowerId': lowerId,
      };

  factory PriorityPin.fromJson(Map<String, dynamic> json) {
    return PriorityPin(
      higherId: json['higherId'] as String,
      lowerId: json['lowerId'] as String,
    );
  }

  @override
  List<Object?> get props => [higherId, lowerId];
}
