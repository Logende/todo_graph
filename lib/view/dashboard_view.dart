import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/filter.dart';
import 'add_node_view.dart';
import 'settings_view.dart';
import 'todo_list_view.dart';

/// View 3 from the spec: the "Kachel" launcher. A grid of large tiles, each
/// representing a saved filter. Tapping a tile opens [TodoListView]
/// pre-filtered.
///
/// Two built-in tiles ("All ongoing", "All goals") are always present so the
/// app is useful before the user has created any custom presets. Any
/// [FilterPreset] in the graph appears as an additional tile, sorted by its
/// `ordering` field if set.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.controller});

  final GraphController controller;

  static const _builtIn = [
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
                builder: (_) => SettingsView(controller: controller),
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
                for (final tile in _builtIn)
                  _Tile(
                    title: tile.title,
                    icon: tile.icon,
                    onTap: () => _openList(context, tile.title, tile.filter),
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

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
