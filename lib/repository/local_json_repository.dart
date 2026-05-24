import 'dart:convert';
import 'dart:io';

import '../model/lakshya_graph.dart';
import 'graph_repository.dart';

/// Persists the Lakshya graph to a single JSON file on the local filesystem.
///
/// The target file is injected so the same implementation can be reused in
/// tests (temp directory) and in the app (`path_provider`-resolved app data
/// directory).
class LocalJsonRepository implements GraphRepository {
  LocalJsonRepository({required this.file});

  final File file;

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
