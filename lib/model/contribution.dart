/// How a child node contributes to a parent goal along an edge.
enum Contribution {
  /// The parent goal is not fulfillable without this child.
  mandatory,

  /// The child assists but is not required for the parent.
  helpful;

  String toJsonValue() => name;

  static Contribution fromJsonValue(String raw) {
    return Contribution.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => throw FormatException('Unknown Contribution: "$raw"'),
    );
  }
}

/// Contribution filter selector used by [Filter]. Adds an explicit "any" option
/// so a saved filter preset can record "I do not care about contribution kind"
/// distinctly from "I have not chosen yet".
enum FilterContribution {
  any,
  mandatory,
  helpful;

  String toJsonValue() => name;

  static FilterContribution fromJsonValue(String raw) {
    return FilterContribution.values.firstWhere(
      (value) => value.name == raw,
      orElse: () =>
          throw FormatException('Unknown FilterContribution: "$raw"'),
    );
  }
}
