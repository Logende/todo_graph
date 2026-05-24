import 'dart:async';

import 'package:flutter/material.dart';

import '../repository/graph_repository.dart';
import '../theme/lakshya_theme.dart';
import '../view/dashboard_view.dart';
import 'graph_controller.dart';
import 'web_file_sync_coordinator.dart';

/// Top-level MaterialApp. The home route is the dashboard; everything else
/// is reached by Navigator.push from there.
///
/// Subscribes to [GraphController.saveErrors] so persistence failures pop a
/// SnackBar at the bottom of the screen — the user finds out their last
/// change didn't get written instead of losing data silently.
class LakshyaApp extends StatefulWidget {
  const LakshyaApp({
    super.key,
    required this.controller,
    this.webFileSync,
    this.fallbackRepository,
    this.recoveryNotice,
  });

  final GraphController controller;
  final WebFileSyncCoordinator? webFileSync;
  final GraphRepository? fallbackRepository;

  /// Optional notice surfaced once at startup — used when main.dart had to
  /// recover from a corrupted save file.
  final String? recoveryNotice;

  @override
  State<LakshyaApp> createState() => _LakshyaAppState();
}

class _LakshyaAppState extends State<LakshyaApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Object>? _saveErrorSubscription;

  @override
  void initState() {
    super.initState();
    _saveErrorSubscription =
        widget.controller.saveErrors.listen(_handleSaveError);
    final notice = widget.recoveryNotice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(notice),
            duration: const Duration(seconds: 8),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _saveErrorSubscription?.cancel();
    super.dispose();
  }

  void _handleSaveError(Object error) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(_messengerKey.currentContext!)
            .colorScheme
            .errorContainer,
        content: Text('Save failed: $error'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () =>
              _messengerKey.currentState?.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lakshya',
      theme: LakshyaTheme.light(),
      darkTheme: LakshyaTheme.dark(),
      scaffoldMessengerKey: _messengerKey,
      home: DashboardView(
        controller: widget.controller,
        webFileSync: widget.webFileSync,
        fallbackRepository: widget.fallbackRepository,
      ),
    );
  }
}
