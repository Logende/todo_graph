import 'package:flutter/material.dart';

import '../theme/lakshya_theme.dart';
import '../view/dashboard_view.dart';
import 'graph_controller.dart';

/// Top-level MaterialApp. The home route is the dashboard; everything else
/// is reached by Navigator.push from there.
class LakshyaApp extends StatelessWidget {
  const LakshyaApp({super.key, required this.controller});

  final GraphController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lakshya',
      theme: LakshyaTheme.light(),
      darkTheme: LakshyaTheme.dark(),
      home: DashboardView(controller: controller),
    );
  }
}
