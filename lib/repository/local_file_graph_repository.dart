import 'dart:convert';
import 'dart:io';

import '../model/lakshya_graph.dart';
import '../service/schema_validator.dart';
import 'graph_repository.dart';

/// Persists the graph as a single JSON file on local disk.
///
/// Intended for desktop app installs where users expect state to survive app
/// restarts in a normal application-support location and where the file can
/// also be inspected or backed up externally.
class LocalFileGraphRepository implements GraphRepository {
  LocalFileGraphRepository({
    required this.file,
    this.validator,
  });

  final File file;
  final SchemaValidator? validator;

  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  Future<LakshyaGraph?> load() async {
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    validator?.validateOrThrow(decoded);
    return LakshyaGraph.fromJson(decoded);
  }

  @override
  Future<void> save(LakshyaGraph graph) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(_encoder.convert(graph.toJson()));
  }
}
