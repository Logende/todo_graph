import '../model/lakshya_graph.dart';

/// Hardcoded, stepwise migrations for persisted graph documents.
///
/// Pre-release we still prefer clean schema evolution, but once users have
/// local files we should upgrade them in-memory instead of rejecting them
/// outright after every schema bump.
class GraphDocumentMigrator {
  const GraphDocumentMigrator();

  Map<String, dynamic> migrate(Map<String, dynamic> input) {
    var working = Map<String, dynamic>.from(input);
    var version = (working['schemaVersion'] as int?) ?? 1;
    while (version < kCurrentSchemaVersion) {
      working = switch (version) {
        1 => _migrateV1ToV2(working),
        _ => throw UnsupportedError(
            'No migration path from schemaVersion=$version',
          ),
      };
      version = working['schemaVersion'] as int;
    }
    return working;
  }

  Map<String, dynamic> _migrateV1ToV2(Map<String, dynamic> json) {
    final next = Map<String, dynamic>.from(json);
    final settingsRaw = json['settings'];
    if (settingsRaw is Map<String, dynamic>) {
      final settings = Map<String, dynamic>.from(settingsRaw);
      final collapsedRaw = settings['collapsedNodeIds'];
      if (collapsedRaw is List) {
        final cleaned = collapsedRaw
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        if (cleaned.isNotEmpty) {
          settings['collapsedNodeIds'] = cleaned;
        } else {
          settings.remove('collapsedNodeIds');
        }
      }
      next['settings'] = settings;
    }
    next['schemaVersion'] = 2;
    return next;
  }
}
