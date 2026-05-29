import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/filter.dart';
import '../model/filter_preset.dart';
import 'add_node_view.dart';
import 'filter_drawer.dart';
import 'task_list_pane.dart';
import 'view_helpers.dart';

/// View 2 from the spec: a flat/tree, filtered, ordered list of tasks with
/// checkboxes for completion.
///
/// This is a thin shell around [TaskListPane] (which renders and edits the
/// rows). It adds the app bar, the "Add task" FAB, and the shared
/// [FilterDrawer]. The filter is held in local state (seeded from the
/// constructor) so the user can refine it on the fly via the right-hand drawer
/// ("Filter & save" icon in the app bar) and save the result as a dashboard
/// tile.
class TodoListView extends StatefulWidget {
  const TodoListView({
    super.key,
    required this.controller,
    required this.title,
    required this.filter,
    this.nowFactory,
  });

  final GraphController controller;
  final String title;
  final Filter filter;

  /// Injectable clock for tests. Defaults to wall clock.
  final DateTime Function()? nowFactory;

  @override
  State<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends State<TodoListView> {
  late Filter _filter = widget.filter;
  final _drawerKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _drawerKey,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _filter.onlyLeaves
                ? 'Showing leaves only — tap to show everything'
                : 'Showing everything — tap to show only leaves',
            icon: Icon(
              _filter.onlyLeaves ? Icons.list_alt : Icons.account_tree_outlined,
            ),
            isSelected: _filter.onlyLeaves,
            onPressed: () => setState(() {
              _filter = _filter.copyWith(onlyLeaves: !_filter.onlyLeaves);
            }),
          ),
          IconButton(
            tooltip: 'Filter & save',
            icon: const Icon(Icons.tune),
            onPressed: () => _drawerKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: FilterDrawer(
        controller: widget.controller,
        filter: _filter,
        onChanged: (next) => setState(() => _filter = next),
        onSaveAsTile: _saveAsTile,
      ),
      floatingActionButton: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final parentId = addTaskParentId(widget.controller, _filter);
          if (parentId == null) return const SizedBox.shrink();
          return FloatingActionButton(
            tooltip: 'Add task',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddNodeView(
                  controller: widget.controller,
                  defaultParentId: parentId,
                ),
              ),
            ),
            child: const Icon(Icons.add),
          );
        },
      ),
      body: TaskListPane(
        controller: widget.controller,
        filter: _filter,
        nowFactory: widget.nowFactory ?? DateTime.now,
      ),
    );
  }

  Future<void> _saveAsTile() async {
    final title = await promptForTileTitle(context, suggestion: widget.title);
    if (title == null) return;
    final preset = FilterPreset(
      id: widget.controller.idGenerator.next(),
      title: title,
      filter: _filter,
      ordering: widget.controller.graph.filterPresets.length,
    );
    widget.controller.setFilterPresets([
      ...widget.controller.graph.filterPresets,
      preset,
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "$title" as a dashboard tile')),
    );
  }
}
