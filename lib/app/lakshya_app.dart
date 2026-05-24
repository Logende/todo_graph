import 'package:flutter/material.dart';

import '../repository/graph_repository.dart';
import '../theme/lakshya_theme.dart';
import '../view/dashboard_view.dart';
import 'graph_controller.dart';
import 'web_file_sync_coordinator.dart';

/// Top-level MaterialApp. The home route is the dashboard; everything else
/// is reached by Navigator.push from there.
class LakshyaApp extends StatelessWidget {
  const LakshyaApp({
    super.key,
    required this.controller,
    this.webFileSync,
    this.fallbackRepository,
  });

  final GraphController controller;

  /// Coordinator for browser File-System-Access-API file sync. Optional so
  /// non-web targets (and widget tests) can construct the app without it.
  final WebFileSyncCoordinator? webFileSync;

  /// The repository the controller falls back to when the user disconnects
  /// file sync.
  final GraphRepository? fallbackRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lakshya',
      theme: LakshyaTheme.light(),
      darkTheme: LakshyaTheme.dark(),
      home: DashboardView(
        controller: controller,
        webFileSync: webFileSync,
        fallbackRepository: fallbackRepository,
      ),
    );
  }
}
