import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/graph_controller.dart';
import 'app/lakshya_app.dart';
import 'app/web_file_sync_coordinator.dart';
import 'model/lakshya_graph.dart';
import 'repository/graph_repository.dart';
import 'repository/local_file_graph_repository.dart';
import 'repository/shared_preferences_graph_repository.dart';
import 'repository/web_graph_file_sync.dart';
import 'service/asset_seed_loader.dart';
import 'service/cloud_sync_registry.dart';
import 'service/id_generator.dart';
import 'service/schema_validator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final validator = await _loadSchemaValidator();
  final cloudSyncRegistry = CloudSyncRegistry.fromEnvironment();
  final fileSync = const WebGraphFileSync();
  final fallback = await _buildFallbackRepository(validator);

  GraphRepository repository = fallback;
  GraphRepository? webFileRepository;
  String? restoredFileName;
  if (kIsWeb && fileSync.isSupported) {
    webFileRepository =
        await fileSync.tryRestoreRepository(validator: validator);
    if (webFileRepository != null) {
      repository = webFileRepository;
      restoredFileName = await fileSync.currentFileName();
    }
  }

  final bootstrap = await _loadOrBootstrapGraph(
    repository: repository,
    validator: validator,
  );
  final controller = GraphController(
    initial: bootstrap.graph,
    save: repository.save,
    idGenerator: UuidV4IdGenerator(),
    clock: DateTime.now,
  );
  final coordinator = WebFileSyncCoordinator(
    fileSync: fileSync,
    controller: controller,
    validator: validator,
    initialFileName: restoredFileName,
  );

  runApp(LakshyaApp(
    controller: controller,
    webFileSync: coordinator,
    fallbackRepository: fallback,
    cloudSyncRegistry: cloudSyncRegistry,
    recoveryNotice: bootstrap.recoveryNotice,
  ));
}

Future<SchemaValidator> _loadSchemaValidator() async {
  final schemaText =
      await rootBundle.loadString('schema/lakshya.schema.json');
  return SchemaValidator.fromString(schemaText);
}

Future<GraphRepository> _buildFallbackRepository(
    SchemaValidator validator) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    final dir = await getApplicationSupportDirectory();
    return LocalFileGraphRepository(
      file: File('${dir.path}/lakshya_graph.json'),
      validator: validator,
    );
  }

  final preferences = await SharedPreferences.getInstance();
  return SharedPreferencesGraphRepository(
    preferences: preferences,
    validator: validator,
  );
}

/// Result of the first-run bootstrap: the graph to hand the controller, plus
/// an optional notice the app should surface (e.g. "your file was corrupt;
/// we backed it up and loaded the example seed instead").
class _BootstrapResult {
  const _BootstrapResult({required this.graph, this.recoveryNotice});
  final LakshyaGraph graph;
  final String? recoveryNotice;
}

Future<_BootstrapResult> _loadOrBootstrapGraph({
  required GraphRepository repository,
  required SchemaValidator validator,
}) async {
  try {
    final loaded = await repository.load();
    if (loaded != null) return _BootstrapResult(graph: loaded);
  } on SchemaValidationException catch (e) {
    // Don't overwrite the broken file — back it up to the side first so the
    // user can hand-recover. If a desktop sidecar backup of the last good
    // save exists, prefer that; otherwise load the example seed.
    final backupPath = await _backupCorruptedRepository(repository);
    final recovered = await _tryLoadLastGoodBackup(repository);
    if (recovered != null) {
      return _BootstrapResult(
        graph: recovered,
        recoveryNotice: backupPath != null
            ? 'Your saved graph failed validation. The broken live file was '
                'preserved at $backupPath and the last known good backup was '
                'loaded instead.\n\nDetails: ${e.errors.take(2).join("; ")}'
            : 'Your saved graph failed validation, so the last known good '
                'backup was loaded instead.',
      );
    }
    final seed = await _loadSeedFromAsset(validator: validator);
    return _BootstrapResult(
      graph: seed,
      recoveryNotice: backupPath != null
          ? 'Your saved graph failed validation. The original was preserved '
              'at $backupPath and the example seed was loaded for now.\n\n'
              'Details: ${e.errors.take(2).join("; ")}'
          : 'Your saved graph failed validation; loaded the example seed '
              'instead. The original was left untouched.',
    );
  }
  // Either there was no saved graph or load returned null — first run.
  final seed = await _loadSeedFromAsset(validator: validator);
  await repository.save(seed);
  return _BootstrapResult(graph: seed);
}

Future<LakshyaGraph?> _tryLoadLastGoodBackup(GraphRepository repository) async {
  if (repository is! LocalFileGraphRepository) return null;
  try {
    return await repository.loadBackup();
  } catch (_) {
    return null;
  }
}

Future<String?> _backupCorruptedRepository(GraphRepository repository) async {
  if (repository is! LocalFileGraphRepository) {
    // Web / preference-backed storage: there's no on-disk path to rename.
    // The caller will fall back to the seed but not save it, so the broken
    // store is left alone.
    return null;
  }
  final live = repository.file;
  if (!await live.exists()) return null;
  final timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  final backup = File('${live.path}.broken-$timestamp');
  try {
    await live.rename(backup.path);
    return backup.path;
  } catch (_) {
    return null;
  }
}

Future<LakshyaGraph> _loadSeedFromAsset({
  required SchemaValidator validator,
}) async {
  final seedJson = await rootBundle.loadString('assets/example_seed.json');
  return AssetSeedLoader(validator: validator).parse(seedJson);
}
