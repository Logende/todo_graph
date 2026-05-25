import '../model/impact.dart';

/// Returns the earlier of two nullable DateTimes. If one is null, returns
/// the other. If both null, returns null.
DateTime? earlierDate(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

/// Returns the Impact with the higher weight. If one is null, returns the
/// other. If both null, returns null.
Impact? strongerImpact(Impact? a, Impact? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.weight >= b.weight ? a : b;
}
