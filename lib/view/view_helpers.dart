import '../model/impact.dart';

/// Formats a [DateTime] as `YYYY-MM-DD` for display in lists and forms.
String formatDate(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

/// Formats a [DateTime] with time component for display.
String formatDateTime(DateTime dt) =>
    '${formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

/// Display labels for the five impact levels.
String impactLabel(Impact level) => switch (level) {
      Impact.minimal => 'Minimal',
      Impact.low => 'Low',
      Impact.medium => 'Medium',
      Impact.high => 'High',
      Impact.critical => 'Critical',
    };

/// Returns null when the text is a positive integer; otherwise a validation
/// error string. Used as a `TextFormField.validator`.
String? validatePositiveInt(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return 'Required';
  final parsed = int.tryParse(trimmed);
  if (parsed == null) return 'Must be a whole number';
  if (parsed < 1) return 'Must be at least 1';
  return null;
}
