import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../app/web_file_sync_coordinator.dart';
import '../model/filter.dart';
import '../model/node.dart';
import '../repository/graph_repository.dart';
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
  });

  final GraphController controller;
  final WebFileSyncCoordinator? webFileSync;
  final GraphRepository? fallbackRepository;

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

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: _columnsForWidth(MediaQuery.sizeOf(context).width),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                for (final tile in _alwaysOnTiles)
                  _Tile(
                    title: tile.title,
                    icon: tile.icon,
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

  static int _columnsForWidth(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
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
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

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
        scale: _hovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
                    Icon(widget.icon, size: 32, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
