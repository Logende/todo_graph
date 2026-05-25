import 'package:flutter/foundation.dart';

import '../repository/graph_repository.dart';
import '../service/cloud_sync_config.dart';
import '../service/cloud_sync_provider.dart';
import 'graph_controller.dart';

typedef ProviderConnector = Future<GraphRepository> Function(
  CloudSyncConfig config,
);

class CloudSyncCoordinator extends ChangeNotifier {
  CloudSyncCoordinator({
    required this.controller,
    required this.fallbackRepository,
    required this.config,
    required this.connectOneDrive,
  });

  final GraphController controller;
  final GraphRepository fallbackRepository;
  final CloudSyncConfig config;
  final ProviderConnector connectOneDrive;

  CloudSyncProviderId? _activeProviderId;
  CloudSyncProviderId? get activeProviderId => _activeProviderId;

  bool get isActive => _activeProviderId != null;
  bool get isOneDriveActive =>
      _activeProviderId == CloudSyncProviderId.oneDrive;

  Future<void> startOneDriveSync() async {
    final repository = await connectOneDrive(config);
    await _adoptRepository(
      repository,
      providerId: CloudSyncProviderId.oneDrive,
    );
  }

  Future<void> stopSync() async {
    controller.replaceSave(fallbackRepository.save);
    _activeProviderId = null;
    notifyListeners();
  }

  Future<void> _adoptRepository(
    GraphRepository repository, {
    required CloudSyncProviderId providerId,
  }) async {
    controller.replaceSave(repository.save);
    final loaded = await repository.load();
    if (loaded != null) {
      controller.replaceWith(loaded);
    } else {
      await repository.save(controller.graph);
    }
    _activeProviderId = providerId;
    notifyListeners();
  }
}
