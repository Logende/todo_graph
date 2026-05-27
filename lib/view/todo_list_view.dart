import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/activation_window.dart';
import '../model/completion.dart';
import '../model/contribution.dart';
import '../model/filter.dart';
import '../model/filter_preset.dart';
import '../model/node.dart';
import '../model/node_status.dart';
import '../model/settings.dart';
import '../service/filter_evaluator.dart';
import '../service/graph_traversal.dart';
import '../service/hierarchical_ordering.dart';
import '../service/node_queries.dart';
import '../widgets/node_picker.dart';
import 'add_node_view.dart';
import 'node_detail_view.dart';
import 'quick_add_child_dialog.dart';

import 'view_helpers.dart';
import '../theme/layout.dart';
/// View 2 from the spec: a flat, filtered, ordered list of tasks with
/// checkboxes for completion.
///
/// The filter is held in local state (seeded from the constructor) so the
/// user can refine it on the fly via the right-hand drawer ("Filter & save"
/// icon in the app bar). The current refined filter can be saved as a
/// dashboard tile via the drawer's "Save as tile" button.
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
              _filter.onlyLeaves
                  ? Icons.list_alt
                  : Icons.account_tree_outlined,
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
      endDrawer: _FilterDrawer(
        controller: widget.controller,
        filter: _filter,
        onChanged: (next) => setState(() => _filter = next),
        onSaveAsTile: _saveAsTile,
      ),
      floatingActionButton: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final parentId = _addParentId(widget.controller, _filter);
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
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final now = (widget.nowFactory ?? DateTime.now).call();
          final queries = NodeQueries(widget.controller.graph);
          final isTreeMode = !_filter.onlyLeaves;
          final filtered = FilterEvaluator(
            graph: widget.controller.graph,
            now: now,
          ).apply(_filter);
          final urgentWindowDays =
              widget.controller.graph.settings?.effectiveUrgentWindowDays ??
                  kDefaultUrgentWindowDays;
          final fullHierarchy = HierarchicalOrdering(
            urgentWindow: Duration(days: urgentWindowDays),
          ).arrange(
            nodes: filtered,
            edges: widget.controller.graph.edges,
            relationships: widget.controller.graph.relationships,
            now: now,
          );
          final collapsedNodeIds =
              widget.controller.graph.settings?.collapsedNodeIds.toSet() ??
                  const <String>{};
          final hierarchy = isTreeMode
              ? _applyCollapsedRows(
                  fullHierarchy,
                  collapsedNodeIds: collapsedNodeIds,
                )
              : fullHierarchy;
          final expandablePathIds =
              isTreeMode ? _expandablePathIds(fullHierarchy) : const <String>{};

          if (hierarchy.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No tasks match this filter.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            // Extra bottom padding so the FAB doesn't overlap the last
            // row's trailing action buttons.
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: hierarchy.length,
            onReorderItem: (oldIndex, newIndex) =>
                _handleReorder(hierarchy, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final row = hierarchy[index];
              final parentId = _parentIdFromPath(row.pathId);
              final edgeContribution = parentId == null
                  ? null
                  : widget.controller.graph.edges
                      .where((e) =>
                          e.childId == row.node.id && e.parentId == parentId)
                      .firstOrNull
                      ?.contribution;
              return _NodeTile(
                key: ValueKey('row-${row.pathId}'),
                index: index,
                node: row.node,
                depth: row.depth,
                now: now,
                queries: queries,
                currentParentId: parentId,
                edgeContribution: edgeContribution,
                isTreeMode: isTreeMode,
                isCollapsed: collapsedNodeIds.contains(row.node.id),
                isExpandable: expandablePathIds.contains(row.pathId),
                onToggleCollapsed: () => _toggleCollapsed(row.node.id),
                onMoveToParent: (currentParentId) =>
                    _moveNodeToParent(row.node, currentParentId),
                onSetCompleted: (isCompleted) =>
                    _setCompletedWithUndo(
                  row.node,
                  isCompleted: isCompleted,
                ),
                onOpenDetail: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NodeDetailView(
                      controller: widget.controller,
                      nodeId: row.node.id,
                    ),
                  ),
                ),
                onQuickAddChild: () => _startQuickAddChild(row.node),
              );
            },
          );
        },
      ),
    );
  }

  void _setCompletedWithUndo(Node node, {required bool isCompleted}) {
    widget.controller.setCompleted(node.id, isCompleted: isCompleted);
    final message = isCompleted
        ? '"${node.title}" completed'
        : '"${node.title}" reopened';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: kUndoSnackBarDuration,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => widget.controller.setCompleted(
              node.id,
              isCompleted: !isCompleted,
            ),
          ),
        ),
      );
  }

  void _toggleCollapsed(String nodeId) {
    final current = widget.controller.graph.settings?.collapsedNodeIds.toSet() ??
        <String>{};
    if (!current.add(nodeId)) {
      current.remove(nodeId);
    }
    widget.controller.setCollapsedNodeIds(current.toList()..sort());
  }

  Future<void> _moveNodeToParent(Node node, String? currentParentId) async {
    if (currentParentId == null) return;
    final traversal = GraphTraversal(widget.controller.graph);
    final excluded = <String>{
      node.id,
      ...traversal.descendantsOf(node.id),
    };
    final target = await showNodePicker(
      context: context,
      nodes: widget.controller.graph.nodes,
      excludeIds: excluded,
      title: 'Move "${node.title}" under…',
    );
    if (target == null) return;
    widget.controller.moveNodeToParent(
      childId: node.id,
      fromParentId: currentParentId,
      toParentId: target.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved "${node.title}" under "${target.title}"')),
    );
  }

  /// Translates a drag in the visible list into one or more
  /// `setMoreImportantThan` calls. Only drops within the same parent at the
  /// same depth are accepted; anything else surfaces a snackbar and snaps
  /// back without state change.
  ///
  /// For each sibling the dragged node crossed, we record one importance
  /// relationship, so the new manual order is preserved next time the list
  /// is built from scratch.
  void _handleReorder(
    List<HierarchicalRow> hierarchy,
    int oldIndex,
    int newIndex,
  ) {
    // onReorderItem reports newIndex already adjusted for the removed source
    // row, so no off-by-one correction is needed.
    if (newIndex == oldIndex) return;

    final moved = hierarchy[oldIndex];
    final movingUp = newIndex < oldIndex;
    final crossed = <HierarchicalRow>[];
    final step = movingUp ? -1 : 1;
    for (var i = oldIndex + step;
        movingUp ? i >= newIndex : i <= newIndex;
        i += step) {
      crossed.add(hierarchy[i]);
    }

    final crossedSiblings = crossed
        .where((r) =>
            r.depth == moved.depth && _sameParentPath(r.pathId, moved.pathId))
        .toList(growable: false);
    final crossedNonSiblings =
        crossed.length - crossedSiblings.length;

    if (crossedNonSiblings > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only siblings under the same parent can be reordered.',
          ),
        ),
      );
      return;
    }
    if (crossedSiblings.isEmpty) return;

    for (final sibling in crossedSiblings) {
      if (movingUp) {
        widget.controller.setMoreImportantThan(
          higherId: moved.node.id,
          lowerId: sibling.node.id,
        );
      } else {
        widget.controller.setMoreImportantThan(
          higherId: sibling.node.id,
          lowerId: moved.node.id,
        );
      }
    }
  }

  /// True when [pathA] and [pathB] share the same parent path — that is,
  /// the prefix up to (but not including) the last segment.
  bool _sameParentPath(String pathA, String pathB) {
    final aSlash = pathA.lastIndexOf('>');
    final bSlash = pathB.lastIndexOf('>');
    if (aSlash != bSlash) return false;
    if (aSlash < 0) return true; // both are top-level
    return pathA.substring(0, aSlash) == pathB.substring(0, bSlash);
  }

  Future<void> _startQuickAddChild(Node parent) async {
    final result = await showQuickAddChild(
      context: context,
      parentTitle: parent.title,
    );
    if (result == null) return;
    if (result is QuickAddSubmission) {
      widget.controller.addChildNode(
        title: result.title,
        parentId: parent.id,
        status: result.status,
        impact: result.impact,
        deadline: result.deadline,
        contribution: result.contribution,
      );
      return;
    }
    if (result is QuickAddEscalation && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AddNodeView(
            controller: widget.controller,
            defaultParentId: parent.id,
            initialTitle: result.title,
            initialStatus: result.status,
            initialContribution: result.contribution,
            initialImpact: result.impact,
            initialDeadline: result.deadline,
          ),
        ),
      );
    }
  }

  Future<void> _saveAsTile() async {
    final title = await _promptForTileTitle(context, suggestion: widget.title);
    if (title == null) return;
    final preset = FilterPreset(
      id: widget.controller.idGenerator.next(),
      title: title,
      filter: _filter,
      ordering: widget.controller.graph.filterPresets.length,
    );
    widget.controller.setFilterPresets(
      [...widget.controller.graph.filterPresets, preset],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "$title" as a dashboard tile')),
    );
  }
}

Future<String?> _promptForTileTitle(
  BuildContext context, {
  required String suggestion,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _SaveAsTileDialog(suggestion: suggestion),
  );
  if (result == null || result.isEmpty) return null;
  return result;
}

class _SaveAsTileDialog extends StatefulWidget {
  const _SaveAsTileDialog({required this.suggestion});
  final String suggestion;

  @override
  State<_SaveAsTileDialog> createState() => _SaveAsTileDialogState();
}

class _SaveAsTileDialogState extends State<_SaveAsTileDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.suggestion);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save as tile'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Tile title'),
        onSubmitted: (_) =>
            Navigator.of(context).pop(_controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Picks a sensible default parent for "Add task" from this view: the first
/// ancestor filter id if present, the configured root otherwise, or the
/// first graph node as a last resort.
String? _addParentId(GraphController controller, Filter filter) {
  if (filter.ancestorGoalIds.isNotEmpty) return filter.ancestorGoalIds.first;
  final configured = controller.graph.settings?.rootNodeId;
  if (configured != null) return configured;
  if (controller.graph.nodes.isNotEmpty) return controller.graph.nodes.first.id;
  return null;
}

class _FilterDrawer extends StatelessWidget {
  const _FilterDrawer({
    required this.controller,
    required this.filter,
    required this.onChanged,
    required this.onSaveAsTile,
  });

  final GraphController controller;
  final Filter filter;
  final ValueChanged<Filter> onChanged;
  final Future<void> Function() onSaveAsTile;

  // Chip options are driven by the enum values — no magic strings.

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Filter',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  ListTile(
                    title: const Text('Goal scope'),
                    subtitle: Text(_scopeTitle()),
                    trailing: IconButton(
                      tooltip: 'Show all goals',
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          onChanged(filter.copyWith(ancestorGoalIds: const [])),
                    ),
                    onTap: () => _pickScope(context),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Show timewise inactive tasks'),
                    subtitle: const Text(
                      'Include future-window tasks and periodic tasks still '
                      'waiting for their next appearance.',
                    ),
                    value: filter.showTimewiseInactiveTasks,
                    onChanged: (v) => onChanged(
                      filter.copyWith(showTimewiseInactiveTasks: v),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Show completed tasks'),
                    subtitle: const Text(
                      'Include one-time and count-based tasks that are already done.',
                    ),
                    value: filter.showCompletedTasks,
                    onChanged: (v) =>
                        onChanged(filter.copyWith(showCompletedTasks: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Only ongoing'),
                    value: filter.onlyOngoing,
                    onChanged: (v) =>
                        onChanged(filter.copyWith(onlyOngoing: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Only leaves'),
                    subtitle: const Text(
                      'Hide intermediate goals; show only the lowest-level '
                      'actionable tasks.',
                    ),
                    value: filter.onlyLeaves,
                    onChanged: (v) =>
                        onChanged(filter.copyWith(onlyLeaves: v)),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Contribution'),
                    subtitle: DropdownButton<FilterContribution>(
                      value: filter.contribution,
                      isExpanded: true,
                      onChanged: (v) => onChanged(
                        filter.copyWith(
                          contribution: v ?? FilterContribution.any,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: FilterContribution.any,
                          child: Text('Any'),
                        ),
                        DropdownMenuItem(
                          value: FilterContribution.mandatory,
                          child: Text('Mandatory only'),
                        ),
                        DropdownMenuItem(
                          value: FilterContribution.helpful,
                          child: Text('Helpful only'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  _EnumChipMultiSelect<CompletionKindFilter>(
                    label: 'Completion kinds',
                    values: CompletionKindFilter.values,
                    selected: filter.completionKinds,
                    labelOf: (v) => v.displayLabel,
                    onChanged: (next) =>
                        onChanged(filter.copyWith(completionKinds: next)),
                  ),
                  const Divider(),
                  _EnumChipMultiSelect<ActivationKindFilter>(
                    label: 'Activation kinds',
                    values: ActivationKindFilter.values,
                    selected: filter.activationKinds,
                    labelOf: (v) => v.displayLabel,
                    onChanged: (next) =>
                        onChanged(filter.copyWith(activationKinds: next)),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: TextFormField(
                      initialValue: filter.freeText ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Free text',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => onChanged(filter.copyWith(freeText: v)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save as tile'),
                onPressed: onSaveAsTile,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _scopeTitle() {
    final selectedId = filter.ancestorGoalIds.isNotEmpty
        ? filter.ancestorGoalIds.first
        : controller.graph.settings?.rootNodeId;
    if (selectedId == null) return 'All goals';
    return controller.graph.nodes
            .where((n) => n.id == selectedId)
            .firstOrNull
            ?.title ??
        'All goals';
  }

  Future<void> _pickScope(BuildContext context) async {
    final parentIds = controller.graph.edges
        .map((e) => e.parentId)
        .toSet();
    final excluded = controller.graph.nodes
        .where((n) => !parentIds.contains(n.id))
        .map((n) => n.id)
        .toSet();
    final selected = await showNodePicker(
      context: context,
      nodes: controller.graph.nodes,
      excludeIds: excluded,
      title: 'Pick a goal',
    );
    if (selected == null) return;
    onChanged(filter.copyWith(ancestorGoalIds: [selected.id]));
  }
}

class _EnumChipMultiSelect<T> extends StatelessWidget {
  const _EnumChipMultiSelect({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final List<T> selected;
  final String Function(T) labelOf;
  final ValueChanged<List<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final value in values)
                FilterChip(
                  label: Text(labelOf(value)),
                  selected: selected.contains(value),
                  onSelected: (isSelected) {
                    final next = [...selected];
                    if (isSelected) {
                      if (!next.contains(value)) next.add(value);
                    } else {
                      next.remove(value);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    super.key,
    required this.index,
    required this.node,
    required this.depth,
    required this.now,
    required this.queries,
    required this.currentParentId,
    required this.edgeContribution,
    required this.isTreeMode,
    required this.isCollapsed,
    required this.isExpandable,
    required this.onToggleCollapsed,
    required this.onMoveToParent,
    required this.onSetCompleted,
    required this.onOpenDetail,
    required this.onQuickAddChild,
  });

  final int index;
  final Node node;
  final int depth;
  final DateTime now;
  final NodeQueries queries;
  final String? currentParentId;
  final Contribution? edgeContribution;
  final bool isTreeMode;
  final bool isCollapsed;
  final bool isExpandable;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<String?> onMoveToParent;
  final ValueChanged<bool> onSetCompleted;
  final VoidCallback onOpenDetail;
  final VoidCallback onQuickAddChild;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < kNarrowScreenBreakpoint;
    final subtitle = _subtitleFor(node, now, isNarrow: isNarrow);
    final scheme = Theme.of(context).colorScheme;
    final indentPerLevel = isNarrow ? kIndentPerLevelNarrow : kIndentPerLevelWide;
    // Cap effective depth so very deep hierarchies don't push the text
    // off-screen.
    final effectiveDepth = depth.clamp(0, kMaxDisplayDepth);
    final borderColor = switch (edgeContribution) {
      Contribution.mandatory => scheme.primary,
      Contribution.helpful => scheme.outlineVariant,
      null => Colors.transparent,
    };
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: edgeContribution != null ? kContributionBorderWidth : 0,
            ),
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.only(
            left: 4 + effectiveDepth * indentPerLevel,
            right: 4,
          ),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTreeMode)
              SizedBox(
                width: isNarrow ? 24 : 28,
                child: isExpandable
                    ? IconButton(
                        tooltip: isCollapsed
                            ? 'Expand child tasks'
                            : 'Collapse child tasks',
                        icon: Icon(
                          isCollapsed
                              ? Icons.chevron_right
                              : Icons.expand_more,
                          size: isNarrow ? kCompactIconSize : kDefaultIconSize,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onToggleCollapsed,
                      )
                    : const SizedBox.shrink(),
              ),
            if (!isNarrow)
              ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: 'Drag to reorder among siblings',
                  child: Icon(
                    Icons.drag_indicator,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            if (!isNarrow) const SizedBox(width: 4),
            _leadingFor(context, isNarrow: isNarrow),
          ],
        ),
        title: Text(
          node.title,
          maxLines: isNarrow ? 2 : null,
          overflow: isNarrow ? TextOverflow.ellipsis : null,
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                maxLines: isNarrow ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isNarrow) _statusBadge(node.status),
            if (isTreeMode && currentParentId != null && !isNarrow)
              IconButton(
                tooltip: 'Move to another parent',
                icon: const Icon(Icons.drive_file_move_outline),
                visualDensity: VisualDensity.compact,
                iconSize: isNarrow ? kCompactIconSize : kDefaultIconSize,
                onPressed: () => onMoveToParent(currentParentId),
              ),
            IconButton(
              tooltip: 'Add child',
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
              iconSize: isNarrow ? kCompactIconSize : kDefaultIconSize,
              onPressed: onQuickAddChild,
            ),
          ],
        ),
        onTap: onOpenDetail,
        ),
      ),
    );
  }

  /// Background goals (no completion concept) can never be "checked off", so
  /// a checkbox would be misleading — they get a goal icon.
  ///
  /// Nodes with completion but still-open mandatory children also can't be
  /// ticked yet — they get a lock icon until their prerequisites close.
  Widget _leadingFor(BuildContext context, {required bool isNarrow}) {
    final iconSize = isNarrow ? kCompactIconSize : kDefaultIconSize;
    if (node.status.completion == null) {
      return Icon(
        Icons.flag_outlined,
        size: iconSize,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    final activation = node.status.activation;
    if (activation is BoundedActive &&
        activation.activeFrom != null &&
        now.isBefore(activation.activeFrom!)) {
      return Tooltip(
        message: 'Not active yet',
        child: Icon(
          Icons.schedule_outlined,
          size: iconSize,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    final blockedByChildren =
        queries.openMandatoryChildrenOf(node.id, now).isNotEmpty;
    if (blockedByChildren) {
      return Tooltip(
        message: 'Mandatory child tasks still open',
        child: Icon(
          Icons.lock_outline,
          size: iconSize,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    return Checkbox(
      visualDensity: isNarrow ? VisualDensity.compact : VisualDensity.standard,
      value: !node.status.isOngoingAt(now),
      onChanged: (value) {
        if (value != null) onSetCompleted(value);
      },
    );
  }

  String? _subtitleFor(Node node, DateTime now, {required bool isNarrow}) {
    final parts = <String>[];
    if (node.description != null && node.description!.isNotEmpty) {
      parts.add(node.description!);
    }
    final inheritedDeadline = queries.inheritedDeadline(node.id);
    if (node.deadline != null) {
      parts.add('Due ${formatDate(node.deadline!)}');
    } else if (inheritedDeadline != null) {
      final suffix = isNarrow ? '' : ' (inherited)';
      parts.add('Due ${formatDate(inheritedDeadline)}$suffix');
    }
    final c = node.status.completion;
    if (c is NTimesCompletion) {
      parts.add('${c.remainingCount} of ${c.targetCount} left');
    } else if (c is PeriodicCompletion) {
      parts.add('Every ${c.intervalDaysSinceLastCompletion}d');
    }
    if (!isNarrow) {
      final a = node.status.activation;
      if (a is BoundedActive) {
        final fromLabel =
            a.activeFrom != null ? formatDate(a.activeFrom!) : '…';
        final untilLabel =
            a.activeUntil != null ? formatDate(a.activeUntil!) : '…';
        parts.add('Active $fromLabel – $untilLabel');
      }
    }
    return parts.isEmpty ? null : parts.join(' • ');
  }

  Widget _statusBadge(NodeStatus status) {
    final completion = status.completion;
    final completionLabel = switch (completion) {
      null => 'goal',
      OneTimeCompletion() => '1×',
      NTimesCompletion() => '${completion.targetCount}×',
      PeriodicCompletion() => 'recurs',
    };
    final boundedSuffix = status.activation is BoundedActive ? ' · window' : '';
    return Chip(
      label: Text(
        '$completionLabel$boundedSuffix',
        style: const TextStyle(fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

}

List<HierarchicalRow> _applyCollapsedRows(
  List<HierarchicalRow> rows, {
  required Set<String> collapsedNodeIds,
}) {
  if (rows.isEmpty || collapsedNodeIds.isEmpty) return rows;
  final visible = <HierarchicalRow>[];
  final collapsedPrefixes = <String>[];
  for (final row in rows) {
    collapsedPrefixes.removeWhere(
      (prefix) => !_isDescendantPath(row.pathId, prefix),
    );
    if (collapsedPrefixes.isNotEmpty) continue;
    visible.add(row);
    if (collapsedNodeIds.contains(row.node.id)) {
      collapsedPrefixes.add(row.pathId);
    }
  }
  return visible;
}

Set<String> _expandablePathIds(List<HierarchicalRow> rows) {
  final out = <String>{};
  for (var i = 0; i < rows.length - 1; i++) {
    if (rows[i + 1].depth > rows[i].depth) out.add(rows[i].pathId);
  }
  return out;
}

bool _isDescendantPath(String path, String ancestorPath) =>
    path.startsWith('$ancestorPath>');

String? _parentIdFromPath(String pathId) {
  final parts = pathId.split('>');
  if (parts.length < 2) return null;
  return parts[parts.length - 2];
}
