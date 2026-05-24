import 'dart:convert';

import '../model/lakshya_graph.dart';
import 'schema_validator.dart';

/// Backs the "Export to JSON" and "Import from JSON" UI actions.
///
/// Import is the only place untrusted JSON enters the app, so it always runs
/// through the [SchemaValidator] before being handed to the model's
/// [LakshyaGraph.fromJson] — invalid documents are rejected with a clear
/// [SchemaValidationException] instead of a deep parse stack trace.
class GraphIo {
  GraphIo({required this.validator});

  final SchemaValidator validator;

  static const _encoder = JsonEncoder.withIndent('  ');

  /// Serialises [graph] to pretty-printed JSON text suitable for an export
  /// file.
  String exportToJson(LakshyaGraph graph) {
    return _encoder.convert(graph.toJson());
  }

  /// Parses [jsonText], validates it against the bundled JSON Schema, and
  /// returns the resulting [LakshyaGraph].
  ///
  /// Throws [FormatException] when [jsonText] is not valid JSON or the root
  /// is not a JSON object. Throws [SchemaValidationException] when the
  /// document is well-formed JSON but does not conform to the schema.
  LakshyaGraph importFromJson(String jsonText) {
    final dynamic decoded;
    try {
      decoded = json.decode(jsonText);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Imported JSON must have an object at the root',
      );
    }
    validator.validateOrThrow(decoded);
    return LakshyaGraph.fromJson(decoded);
  }
}
