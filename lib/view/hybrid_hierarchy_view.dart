import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/filter.dart';
import '../model/filter_preset.dart';
import '../theme/layout.dart';
import 'add_node_view.dart';
import 'filter_drawer.dart';
import 'hybrid_graph_pane.dart';
import 'task_list_pane.dart';
import 'view_helpers.dart';

/// The shared task explorer shell. It owns the live filter, the display mode
/// (tree list vs graph), and the graph view settings, and hosts the app-bar
/// controls and filter drawer. The actual rendering is delegated:
///
/// * tree-list mode → [TaskListPane] (the classic indented list)
/// * graph mode → [HybridGraphPane] (the column-per-level graph)
///
/// Graph-specific controls (level navigation, zoom, fit, parent placement) are
/// only shown in graph mode and drive the pane through a
/// [HybridGraphPaneController].
class HybridHierarchyView extends StatefulWidget {
  const HybridHierarchyView({
    super.key,
    required this.controller,
    this.title = 'Hybrid',
    this.filter = const Filter(),
    this.viewSettings = const ExplorerViewSettings(
      displayMode: ExplorerDisplayMode.graph,
    ),
    this.onViewSettingsChanged,
  });

  final GraphController controller;
  final String title;
  final Filter filter;
  final ExplorerViewSettings viewSettings;

  /// Called whenever the user changes a view setting (display mode, parent
  /// placement). The dashboard uses this to persist the setting for built-in
  /// and auto-generated tiles so it is restored next time the tile is opened.
  /// Null for tiles that should not persist (e.g. saved presets).
  final ValueChanged<ExplorerViewSettings>? onViewSettingsChanged;

  @override
  State<HybridHierarchyView> createState() => _HybridHierarchyViewState();
}

class _HybridHierarchyViewState extends State<HybridHierarchyView> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _graphPane = HybridGraphPaneController();
  late Filter _filter = widget.filter;
  late ExplorerDisplayMode _displayMode = widget.viewSettings.displayMode;
  late bool _centerParents = widget.viewSettings.centerGraphParents;
  late final ExplorerGraphFlow _graphFlow = widget.viewSettings.graphFlow;
  HybridGraphLevelInfo _graphLevelInfo = HybridGraphLevelInfo.empty;

  bool get _isGraphMode => _displayMode == ExplorerDisplayMode.graph;
  Filter get _filterForCurrentMode => _isGraphMode && _filter.onlyLeaves
      ? _filter.copyWith(onlyLeaves: false)
      : _filter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _appBarTitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: _appBarActions(context),
      ),
      endDrawer: FilterDrawer(
        controller: widget.controller,
        filter: _filterForCurrentMode,
        onChanged: (next) {
          setState(() => _filter = next);
          _graphPane.resetToFirstLevel();
        },
        onSaveAsTile: _saveAsTile,
        showOnlyLeavesOption: !_isGraphMode,
      ),
      floatingActionButton: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final parentId = addTaskParentId(
            widget.controller,
            _filterForCurrentMode,
          );
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
      body: _isGraphMode
          ? HybridGraphPane(
              controller: widget.controller,
              filter: _filterForCurrentMode,
              graphFlow: _graphFlow,
              centerParents: _centerParents,
              paneController: _graphPane,
              onLevelInfoChanged: (info) {
                if (mounted) setState(() => _graphLevelInfo = info);
              },
            )
          : TaskListPane(
              controller: widget.controller,
              filter: _filter,
              nowFactory: widget.controller.clock,
            ),
    );
  }

  String _appBarTitle() {
    if (_isGraphMode && _graphLevelInfo.levelCount > 0) {
      final label =
          _graphLevelInfo.focusedLevelLabel ??
          'Level ${_graphLevelInfo.focusedLevel + 1}';
      return '${widget.title} · $label';
    }
    return widget.title;
  }

  List<Widget> _appBarActions(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < kNarrowScreenBreakpoint;
    final primary = [
      IconButton(
        tooltip: _isGraphMode ? 'Show tree list' : 'Show graph',
        icon: Icon(
          _isGraphMode ? Icons.account_tree_outlined : Icons.hub_outlined,
        ),
        onPressed: _toggleDisplayMode,
      ),
    ];
    // Level navigation only makes sense in the graph view.
    final levelNav = [
      IconButton(
        tooltip: 'Previous level',
        icon: const Icon(Icons.chevron_left),
        onPressed: _graphPane.previousLevel,
      ),
      IconButton(
        tooltip: 'Next level',
        icon: const Icon(Icons.chevron_right),
        onPressed: _graphPane.nextLevel,
      ),
    ];
    final zoom = [
      IconButton(
        tooltip: 'Zoom out',
        icon: const Icon(Icons.remove),
        onPressed: _graphPane.zoomOut,
      ),
      IconButton(
        tooltip: 'Zoom in',
        icon: const Icon(Icons.add),
        onPressed: _graphPane.zoomIn,
      ),
      IconButton(
        tooltip: 'Fit current level',
        icon: const Icon(Icons.fit_screen),
        onPressed: _graphPane.fitCurrentLevel,
      ),
      IconButton(
        tooltip: _centerParents
            ? 'Pack levels as lists'
            : 'Center parents over children',
        icon: Icon(
          _centerParents
              ? Icons.format_list_bulleted
              : Icons.align_vertical_center,
        ),
        onPressed: _toggleParentPlacement,
      ),
    ];
    final common = [
      if (!_isGraphMode)
        IconButton(
          // Like the display-mode toggle, the icon and tooltip describe what
          // tapping does, not the current state.
          tooltip: _filter.onlyLeaves ? 'Show whole tree' : 'Show leaves only',
          icon: Icon(
            _filter.onlyLeaves ? Icons.account_tree_outlined : Icons.list_alt,
          ),
          onPressed: () => setState(() {
            _filter = _filter.copyWith(onlyLeaves: !_filter.onlyLeaves);
          }),
        ),
      IconButton(
        tooltip: 'Filter',
        icon: const Icon(Icons.tune),
        onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
      IconButton(
        tooltip: 'Save current view as tile',
        icon: const Icon(Icons.bookmark_add_outlined),
        onPressed: _saveAsTile,
      ),
    ];
    if (!isNarrow) {
      return [
        ...primary,
        if (_isGraphMode) ...levelNav,
        if (_isGraphMode) ...zoom,
        ...common,
      ];
    }
    return [
      ...primary,
      if (_isGraphMode) ...levelNav,
      if (_isGraphMode)
        PopupMenuButton<_HybridViewAction>(
          tooltip: 'View controls',
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            switch (action) {
              case _HybridViewAction.zoomOut:
                _graphPane.zoomOut();
              case _HybridViewAction.zoomIn:
                _graphPane.zoomIn();
              case _HybridViewAction.fitLevel:
                _graphPane.fitCurrentLevel();
              case _HybridViewAction.togglePlacement:
                _toggleParentPlacement();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _HybridViewAction.zoomOut,
              child: ListTile(
                leading: Icon(Icons.remove),
                title: Text('Zoom out'),
              ),
            ),
            const PopupMenuItem(
              value: _HybridViewAction.zoomIn,
              child: ListTile(leading: Icon(Icons.add), title: Text('Zoom in')),
            ),
            const PopupMenuItem(
              value: _HybridViewAction.fitLevel,
              child: ListTile(
                leading: Icon(Icons.fit_screen),
                title: Text('Fit current level'),
              ),
            ),
            PopupMenuItem(
              value: _HybridViewAction.togglePlacement,
              child: ListTile(
                leading: Icon(
                  _centerParents
                      ? Icons.format_list_bulleted
                      : Icons.align_vertical_center,
                ),
                title: Text(
                  _centerParents
                      ? 'Pack levels as lists'
                      : 'Center parents over children',
                ),
              ),
            ),
          ],
        ),
      ...common,
    ];
  }

  void _toggleDisplayMode() {
    setState(() {
      _displayMode = _isGraphMode
          ? ExplorerDisplayMode.treeList
          : ExplorerDisplayMode.graph;
    });
    _persistViewSettings();
  }

  void _toggleParentPlacement() {
    setState(() => _centerParents = !_centerParents);
    _graphPane.refocusCurrentLevel();
    _persistViewSettings();
  }

  void _persistViewSettings() =>
      widget.onViewSettingsChanged?.call(_currentViewSettings());

  Future<void> _saveAsTile() async {
    final title = await promptForTileTitle(context, suggestion: widget.title);
    if (title == null) return;
    final preset = FilterPreset(
      id: widget.controller.idGenerator.next(),
      title: title,
      filter: _filterForCurrentMode,
      viewSettings: _currentViewSettings(),
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

  ExplorerViewSettings _currentViewSettings() => ExplorerViewSettings(
    displayMode: _displayMode,
    graphFlow: _graphFlow,
    centerGraphParents: _centerParents,
  );
}

enum _HybridViewAction { zoomOut, zoomIn, fitLevel, togglePlacement }
