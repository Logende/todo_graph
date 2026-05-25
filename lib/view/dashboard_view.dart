import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../app/web_file_sync_coordinator.dart';
import '../model/filter.dart';
import '../model/node.dart';
import '../repository/graph_repository.dart';
import '../service/cloud_sync_registry.dart';
import '../service/filter_evaluator.dart';
import '../theme/layout.dart';
import 'add_node_view.dart';
import 'graph_canvas_view.dart';
import 'settings_view.dart';
import 'todo_list_view.dart';

/// View 3 from the spec: the "Kachel" launcher. A grid of large tiles, each
/// representing a saved filter, the graph view, or a top-level life area.
/// Tapping a list-style tile opens [TodoListView] pre-filtered; the graph
/// tile opens [GraphCanvasView].
///
/// Tile sources:
/// * Two built-in tiles: "All ongoing" and "All goals".
/// * One built-in tile for the graph view.
/// * One auto-tile per direct child of the root goal (so "Health", "Work",
///   "Leisure", etc. all get a dedicated tile without the user having to
///   save a preset for them).
/// * Any [FilterPreset] the user has saved (via the "Save as tile" button on
///   the todo list).
class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.controller,
    this.webFileSync,
    this.fallbackRepository,
    this.cloudSyncRegistry,
  });

  final GraphController controller;
  final WebFileSyncCoordinator? webFileSync;
  final GraphRepository? fallbackRepository;
  final CloudSyncRegistry? cloudSyncRegistry;

  static const _alwaysOnTiles = [
    _BuiltInTile(
      title: 'All ongoing',
      icon: Icons.local_fire_department_outlined,
      filter: Filter(onlyOngoing: true, onlyLeaves: true),
    ),
    _BuiltInTile(
      title: 'All goals',
      icon: Icons.account_tree_outlined,
      filter: Filter(),
    ),
  ];

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
              crossAxisCount: _columnsForWidth(MediaQuery.sizeOf(context).width),
              mainAxisSpacing: kTileGridSpacing,
              crossAxisSpacing: kTileGridSpacing,
              childAspectRatio: kTileAspectRatio,
              children: [
                for (final tile in _alwaysOnTiles)
                  _Tile(
                    title: tile.title,
                    icon: tile.icon,
                    badge: _actionableCount(tile.filter, now),
                    onTap: () => _openList(context, tile.title, tile.filter),
                  ),
                _Tile(
                  title: 'Graph',
                  icon: Icons.hub_outlined,
                  onTap: () => _openGraph(context),
                ),
                for (final child in rootChildren)
                  _Tile(
                    title: child.title,
                    icon: Icons.folder_outlined,
                    badge: _actionableCount(
                      Filter(ancestorGoalIds: [child.id]),
                      now,
                    ),
                    onTap: () => _openList(
                      context,
                      child.title,
                      Filter(ancestorGoalIds: [child.id]),
                    ),
                  ),
                for (final preset in presets)
                  _Tile(
                    title: preset.title,
                    icon: Icons.filter_alt_outlined,
                    badge: _actionableCount(preset.filter, now),
                    onTap: () =>
                        _openList(context, preset.title, preset.filter),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openList(BuildContext context, String title, Filter filter) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TodoListView(
        controller: controller,
        title: title,
        filter: filter,
      ),
    ));
  }

  void _openGraph(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GraphCanvasView(controller: controller),
    ));
  }

  int _actionableCount(Filter baseFilter, DateTime now) {
    final actionable = baseFilter.copyWith(
      onlyOngoing: true,
      onlyLeaves: true,
    );
    return FilterEvaluator(graph: controller.graph, now: now)
        .apply(actionable)
        .length;
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
                  scheme.primary.withValues(
                    alpha: _hovered ? 0.10 : 0.04,
                  ),
                  scheme.surfaceContainerHigh,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: _hovered ? 0.18 : 0.08,
                ),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
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
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
