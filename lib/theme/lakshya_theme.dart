import 'package:flutter/material.dart';

/// Material 3 theme tuned for the Shiva motif: a warm saffron primary against
/// a deep indigo, suggesting flame and twilight. Polished iconography and a
/// proper logo come later in Phase 7.
class LakshyaTheme {
  LakshyaTheme._();

  static const Color _saffron = Color(0xFFD9531E);
  static const Color _indigo = Color(0xFF1A1A2E);
  static const Color _ash = Color(0xFFEDE6D8);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _saffron,
      brightness: Brightness.light,
      surface: _ash,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _saffron,
      brightness: Brightness.dark,
      surface: _indigo,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
