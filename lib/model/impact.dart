/// User-assigned estimate of how impactful completing a node is. Fixed
/// five-step scale so the default ordering can compare nodes directly without
/// the user having to invent arbitrary numbers.
///
/// [weight] is the numeric value used in ordering calculations; higher means
/// ranks earlier when other factors tie.
enum Impact {
  minimal(weight: 1),
  low(weight: 2),
  medium(weight: 3),
  high(weight: 4),
  critical(weight: 5);

  const Impact({required this.weight});

  final int weight;

  String toJsonValue() => name;

  static Impact fromJsonValue(String raw) {
    return Impact.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => throw FormatException('Unknown Impact: "$raw"'),
    );
  }
}
