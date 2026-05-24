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
    // Atomic write: stream into a temp file, fsync it, then rename over the
    // live file. A crash mid-write leaves the live file untouched. The temp
    // is in the same directory so the rename stays on one filesystem (which
    // is what POSIX requires for an atomic operation).
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(
        _encoder.convert(graph.toJson()),
        flush: true,
      );
      await temp.rename(file.path);
    } catch (_) {
      // Best-effort cleanup of the half-written temp; rethrow so the caller
      // can surface a useful error.
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {/* ignore */}
      }
      rethrow;
    }
  }
}
