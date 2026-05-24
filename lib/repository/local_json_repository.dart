import 'dart:convert';
import 'dart:io';

import '../model/lakshya_graph.dart';
import '../service/schema_validator.dart';
import 'graph_repository.dart';

/// Persists the Lakshya graph to a single JSON file on the local filesystem.
///
/// The target file is injected so the same implementation can be reused in
/// tests (temp directory) and in the app (`path_provider`-resolved app data
/// directory). An optional [validator] is run against the decoded JSON on
/// every [load] so external or corrupted files surface a useful error
/// instead of a generic parse crash.
class LocalJsonRepository implements GraphRepository {
  LocalJsonRepository({required this.file, this.validator});

  final File file;
  final SchemaValidator? validator;

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  @override
  Future<LakshyaGraph?> load() async {
    if (!await file.exists()) {
      return null;
    }
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }
    final decoded = json.decode(raw) as Map<String, dynamic>;
    validator?.validateOrThrow(decoded);
    return LakshyaGraph.fromJson(decoded);
  }

  @override
  Future<void> save(LakshyaGraph graph) async {
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final serialised = _jsonEncoder.convert(graph.toJson());
    await file.writeAsString(serialised, flush: true);
  }
}
