import 'dart:convert';

import 'package:json_schema/json_schema.dart';

/// Runtime validator that checks decoded JSON against
/// `schema/lakshya.schema.json` before it is handed off to the hand-written
/// model classes.
///
/// The model's `fromJson` constructors trust their input. The validator is
/// the gate that catches malformed on-disk data (manual edits, corrupted
/// files, older schema versions, foreign documents) with actionable error
/// messages instead of a generic null-deref crash deep inside parsing.
class SchemaValidator {
  SchemaValidator(this._schema);

  factory SchemaValidator.fromMap(Map<String, dynamic> schemaJson) {
    return SchemaValidator(JsonSchema.create(schemaJson));
  }

  factory SchemaValidator.fromString(String schemaJsonText) {
    return SchemaValidator.fromMap(
      json.decode(schemaJsonText) as Map<String, dynamic>,
    );
  }

  final JsonSchema _schema;

  /// Returns true when [instance] conforms to the schema.
  bool isValid(Object? instance) => _schema.validate(instance).isValid;

  /// Validates [instance] against the schema. Throws
  /// [SchemaValidationException] with the full error list on failure.
  void validateOrThrow(Object? instance) {
    final result = _schema.validate(instance);
    if (!result.isValid) {
      throw SchemaValidationException(
        errors: result.errors
            .map((e) => e.toString())
            .toList(growable: false),
      );
    }
  }
}

class SchemaValidationException implements Exception {
  const SchemaValidationException({required this.errors});

  final List<String> errors;

  @override
  String toString() =>
      'SchemaValidationException: ${errors.join('; ')}';
}
