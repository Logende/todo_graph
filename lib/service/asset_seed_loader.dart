import 'dart:convert';

import '../model/lakshya_graph.dart';
import 'schema_validator.dart';

/// Loads the first-run seed graph from a bundled JSON asset (or any string
/// the caller supplies). The seed is validated against the same schema as
/// user imports, so editing `assets/example_seed.json` by hand surfaces
/// mistakes immediately instead of crashing inside model parsing.
class AssetSeedLoader {
  AssetSeedLoader({required this.validator});

  final SchemaValidator validator;

  /// Parses a previously-read seed file body. Caller is responsible for
  /// reading the asset (typically via `rootBundle.loadString`).
  LakshyaGraph parse(String jsonText) {
    final decoded = json.decode(jsonText) as Map<String, dynamic>;
    validator.validateOrThrow(decoded);
    return LakshyaGraph.fromJson(decoded);
  }
}
