import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/lakshya_graph.dart';
import '../service/schema_validator.dart';
import 'graph_repository.dart';

/// Persists the Lakshya graph as a single pretty-printed JSON string in
/// `shared_preferences`. Works on every platform Flutter targets without
/// per-platform plugin configuration (web stores it in `localStorage`,
/// native stores it in the platform's preference store).
///
/// An optional [validator] gates every load: malformed or out-of-shape
/// documents raise [SchemaValidationException] instead of crashing inside
/// model parsing.
class SharedPreferencesGraphRepository implements GraphRepository {
  SharedPreferencesGraphRepository({
    required this.preferences,
    this.validator,
  });

  /// Storage key for the serialised graph document.
  static const String storageKey = 'lakshya.graph';

  final SharedPreferences preferences;
  final SchemaValidator? validator;

  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  Future<LakshyaGraph?> load() async {
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    validator?.validateOrThrow(decoded);
    return LakshyaGraph.fromJson(decoded);
  }

  @override
  Future<void> save(LakshyaGraph graph) async {
    await preferences.setString(storageKey, _encoder.convert(graph.toJson()));
  }
}
