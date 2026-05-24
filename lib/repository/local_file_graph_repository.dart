import 'dart:convert';
import 'dart:io';

import '../model/lakshya_graph.dart';
import '../service/graph_document_migrator.dart';
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
    this.migrator = const GraphDocumentMigrator(),
  });

  final File file;
  final SchemaValidator? validator;
  final GraphDocumentMigrator migrator;
  File get backupFile => File('${file.path}.backup');

  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  Future<LakshyaGraph?> load() async {
    if (!await file.exists()) return null;
    return _decodeFile(file);
  }

  Future<LakshyaGraph?> loadBackup() async {
    if (!await backupFile.exists()) return null;
    return _decodeFile(backupFile);
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
      try {
        await file.copy(backupFile.path);
      } catch (_) {
        // The primary save already succeeded. Keep the backup best-effort so
        // a sidecar copy failure does not surface as "save failed".
      }
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

  Future<LakshyaGraph?> _decodeFile(File source) async {
    final raw = await source.readAsString();
    if (raw.trim().isEmpty) return null;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final migrated = migrator.migrate(decoded);
    validator?.validateOrThrow(migrated);
    return LakshyaGraph.fromJson(migrated);
  }
}
