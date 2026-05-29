import 'package:flutter/material.dart';

import '../app/cloud_sync_coordinator.dart';
import '../app/graph_controller.dart';
import '../app/web_file_sync_coordinator.dart';
import '../model/filter.dart';
import '../model/filter_preset.dart';
import '../model/node.dart';
import '../repository/graph_repository.dart';
import '../service/cloud_sync_registry.dart';
import '../service/filter_evaluator.dart';
import '../theme/layout.dart';
import 'add_node_view.dart';
import 'hybrid_hierarchy_view.dart';
import 'settings_view.dart';

/// View 3 from the spec: the "Kachel" launcher. A grid of large tiles, each
/// representing the shared task explorer, a saved tile, or a top-level life
/// area.
/// Tapping a tile opens [HybridHierarchyView], the shared task explorer,
/// pre-filtered and pre-configured by the tile.
///
/// Tile sources:
/// * One built-in tile: "All".
/// * One auto-tile per direct child of the root goal (so "Health", "Work",
///   "Leisure", etc. all get a dedicated tile without the user having to
///   save a preset for them).
/// * Any [FilterPreset] the user has saved.
class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.controller,
    this.webFileSync,
    this.fallbackRepository,
    this.cloudSyncRegistry,
    this.cloudSyncCoordinator,
  });

  final GraphController controller;
  final WebFileSyncCoordinator? webFileSync;
  final GraphRepository? fallbackRepository;
  final CloudSyncRegistry? cloudSyncRegistry;
  final CloudSyncCoordinator? cloudSyncCoordinator;

  static const _builtInTile = _BuiltInTile(
    title: 'All',
    icon: Icons.account_tree_outlined,
    filter: Filter(),
  );

  /// Stable, collision-free persistence keys for the non-preset tiles whose
  /// view settings (graph vs list, etc.) are remembered between sessions.
  static const _allTileKey = 'tile:all';
  static String _goalTileKey(String nodeId) => 'tile:goal:$nodeId';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lakshya'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsView(
                  controller: controller,
                  webFileSync: webFileSync,
                  fallbackRepository: fallbackRepository,
                  cloudSyncRegistry: cloudSyncRegistry,
                  cloudSyncCoordinator: cloudSyncCoordinator,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final rootId = _rootParentId(controller);
          if (rootId == null) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddNodeView(
                  controller: controller,
                  defaultParentId: rootId,
                ),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add task'),
          );
        },
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final rootChildren = _directChildrenOfRoot(controller);
          final presets = [...controller.graph.filterPresets]
            ..sort((a, b) => (a.ordering ?? 0).compareTo(b.ordering ?? 0));

          final now = controller.clock();

          return Padding(
            padding: const EdgeInsets.all(kTileGridPadding),
            child: GridView.count(
              crossAxisCount: _columnsForWidth(
                MediaQuery.sizeOf(context).width,
              ),
              mainAxisSpacing: kTileGridSpacing,
              crossAxisSpacing: kTileGridSpacing,
              childAspectRatio: kTileAspectRatio,
              children: [
                _Tile(
                  title: _builtInTile.title,
                  icon: _builtInTile.icon,
                  badge: _actionableCount(_builtInTile.filter, now),
                  onTap: () => _openExplorer(
                    context,
                    title: _builtInTile.title,
                    filter: _builtInTile.filter,
                    viewSettings: _storedViewSettings(_allTileKey),
                    persistKey: _allTileKey,
                  ),
                ),
                for (final child in rootChildren)
                  _Tile(
                    title: child.title,
                    icon: Icons.folder_outlined,
                    badge: _actionableCount(
                      Filter(ancestorGoalIds: [child.id]),
                      now,
                    ),
                    onTap: () => _openExplorer(
                      context,
                      title: child.title,
                      filter: Filter(ancestorGoalIds: [child.id]),
                      viewSettings: _storedViewSettings(_goalTileKey(child.id)),
                      persistKey: _goalTileKey(child.id),
                    ),
                  ),
                for (final preset in presets)
                  _Tile(
                    title: preset.title,
                    icon: Icons.filter_alt_outlined,
                    badge: _actionableCount(preset.filter, now),
                    onTap: () => _openExplorer(
                      context,
                      title: preset.title,
                      filter: preset.filter,
                      viewSettings: preset.viewSettings,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// View settings stored for a non-preset tile, defaulting to a plain
  /// [ExplorerViewSettings] when nothing has been persisted yet.
  ExplorerViewSettings _storedViewSettings(String tileKey) =>
      controller.graph.settings?.tileViewSettings[tileKey] ??
      const ExplorerViewSettings();

  void _openExplorer(
    BuildContext context, {
    required String title,
    required Filter filter,
    required ExplorerViewSettings viewSettings,
    String? persistKey,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HybridHierarchyView(
          controller: controller,
          title: title,
          filter: filter,
          viewSettings: viewSettings,
          onViewSettingsChanged: persistKey == null
              ? null
              : (next) => controller.setTileViewSettings(persistKey, next),
        ),
      ),
    );
  }

  int _actionableCount(Filter baseFilter, DateTime now) {
    final actionable = baseFilter.copyWith(onlyOngoing: true, onlyLeaves: true);
    return FilterEvaluator(
      graph: controller.graph,
      now: now,
    ).apply(actionable).length;
  }

  static int _columnsForWidth(double width) {
    if (width >= kWideScreenBreakpoint) return 4;
    if (width >= kMediumScreenBreakpoint) return 3;
    return 2;
  }

  /// Returns the configured root node id, falling back to the first node in
  /// the graph if no settings have been written yet. Returns null only for an
  /// empty graph (no nodes at all).
  static String? _rootParentId(GraphController controller) {
    final configured = controller.graph.settings?.rootNodeId;
    if (configured != null) return configured;
    if (controller.graph.nodes.isNotEmpty) {
      return controller.graph.nodes.first.id;
    }
    return null;
  }

  static List<Node> _directChildrenOfRoot(GraphController controller) {
    final rootId = _rootParentId(controller);
    if (rootId == null) return const [];
    final nodeById = {for (final n in controller.graph.nodes) n.id: n};
    final children = <Node>[];
    final seen = <String>{};
    for (final edge in controller.graph.edges) {
      if (edge.parentId != rootId) continue;
      if (!seen.add(edge.childId)) continue;
      final child = nodeById[edge.childId];
      if (child != null) children.add(child);
    }
    return children;
  }
}

class _BuiltInTile {
  const _BuiltInTile({
    required this.title,
    required this.icon,
    required this.filter,
  });
  final String title;
  final IconData icon;
  final Filter filter;
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? kTileHoverScale : 1.0,
        duration: kHoverScaleDuration,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: kHoverColorDuration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerHigh,
                Color.alphaBlend(
                  scheme.primary.withValues(alpha: _hovered ? 0.10 : 0.04),
                  scheme.surfaceContainerHigh,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: _hovered ? 0.18 : 0.08),
                blurRadius: _hovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(widget.icon, size: 32, color: scheme.primary),
                        if (widget.badge != null && widget.badge! > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${widget.badge}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
