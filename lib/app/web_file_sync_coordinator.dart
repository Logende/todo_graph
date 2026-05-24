import 'package:flutter/foundation.dart';

import '../model/lakshya_graph.dart';
import '../repository/graph_repository.dart';
import '../repository/web_graph_file_sync.dart';
import '../service/schema_validator.dart';
import 'graph_controller.dart';

/// Glue between [WebGraphFileSync] and the running [GraphController]: drives
/// the file-picker flow, swaps the controller's save target on success, and
/// publishes the currently-synced file's display name so the UI can react.
class WebFileSyncCoordinator extends ChangeNotifier {
  WebFileSyncCoordinator({
    required this.fileSync,
    required this.controller,
    required this.validator,
    String? initialFileName,
  }) : _fileName = initialFileName;

  final WebGraphFileSync fileSync;
  final GraphController controller;
  final SchemaValidator validator;

  String? _fileName;
  String? get currentFileName => _fileName;

  bool get isSupported => fileSync.isSupported;
  bool get isActive => _fileName != null;

  /// Opens the "save as" picker so the user picks (or creates) a file to use
  /// as the new backing store. On success, the current in-memory graph is
  /// flushed to the file and every subsequent save goes there.
  ///
  /// Returns true when a file was picked.
  Future<bool> startSyncToNewFile({
    required String suggestedName,
  }) async {
    final repository = await fileSync.pickFileAsBackingStore(
      validator: validator,
      suggestedName: suggestedName,
    );
    if (repository == null) return false;
    await _adoptRepository(repository, seedWithCurrentGraph: true);
    return true;
  }

  /// Disconnects the file sync. The on-disk file is left untouched; future
  /// saves go through [fallback].
  Future<void> stopSync({required GraphRepository fallback}) async {
    await fileSync.forget();
    controller.replaceSave(fallback.save);
    _fileName = null;
    notifyListeners();
  }

  Future<void> _adoptRepository(
    GraphRepository repository, {
    required bool seedWithCurrentGraph,
  }) async {
    controller.replaceSave(repository.save);
    if (seedWithCurrentGraph) {
      await repository.save(controller.graph);
    } else {
      final loaded = await repository.load();
      if (loaded != null) controller.replaceWith(loaded);
    }
    _fileName = await fileSync.currentFileName();
    notifyListeners();
  }

  /// Replaces the in-memory graph with [graph] and persists it through the
  /// current target. Used after a restored file is read on startup.
  Future<void> adoptLoadedGraph(LakshyaGraph graph) async {
    controller.replaceWith(graph);
    _fileName = await fileSync.currentFileName();
    notifyListeners();
  }
}
