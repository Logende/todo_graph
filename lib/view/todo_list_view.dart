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
import '../service/hierarchical_ordering.dart';
import 'add_node_view.dart';
import 'node_detail_view.dart';
import 'quick_add_child_dialog.dart';

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
            tooltip: 'Filter & save',
            icon: const Icon(Icons.tune),
            onPressed: () => _drawerKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _FilterDrawer(
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
          final filtered = FilterEvaluator(
            graph: widget.controller.graph,
            now: now,
          ).apply(_filter);
          final urgentWindowDays =
              widget.controller.graph.settings?.effectiveUrgentWindowDays ??
                  kDefaultUrgentWindowDays;
          final hierarchy = HierarchicalOrdering(
            urgentWindow: Duration(days: urgentWindowDays),
          ).arrange(
            nodes: filtered,
            edges: widget.controller.graph.edges,
            relationships: widget.controller.graph.relationships,
            now: now,
          );

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

          return ListView.separated(
            itemCount: hierarchy.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = hierarchy[index];
              return _NodeTile(
                key: ValueKey('row-${row.pathId}'),
                node: row.node,
                depth: row.depth,
                now: now,
                onToggleComplete: () =>
                    widget.controller.markCompleted(row.node.id),
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
      );
      return;
    }
    if (result is QuickAddEscalation && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AddNodeView(
            controller: widget.controller,
            defaultParentId: parent.id,
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
    final next = widget.controller.graph.copyWith(
      filterPresets: [...widget.controller.graph.filterPresets, preset],
    );
    widget.controller.replaceWith(next);
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
    required this.filter,
    required this.onChanged,
    required this.onSaveAsTile,
  });

  final Filter filter;
  final ValueChanged<Filter> onChanged;
  final Future<void> Function() onSaveAsTile;

  static const _completionKinds = ['none', 'one_time', 'n_times', 'periodic'];
  static const _activationKinds = ['always_active', 'bounded'];

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
                  SwitchListTile(
                    title: const Text('Only ongoing'),
                    value: filter.onlyOngoing,
                    onChanged: (v) =>
                        onChanged(_copyFilter(onlyOngoing: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Only leaves'),
                    value: filter.onlyLeaves,
                    onChanged: (v) =>
                        onChanged(_copyFilter(onlyLeaves: v)),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Contribution'),
                    subtitle: DropdownButton<FilterContribution>(
                      value: filter.contribution,
                      isExpanded: true,
                      onChanged: (v) => onChanged(
                        _copyFilter(
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
                  _ChipMultiSelect(
                    label: 'Completion kinds',
                    options: _completionKinds,
                    selected: filter.completionKinds,
                    onChanged: (next) =>
                        onChanged(_copyFilter(completionKinds: next)),
                  ),
                  const Divider(),
                  _ChipMultiSelect(
                    label: 'Activation kinds',
                    options: _activationKinds,
                    selected: filter.activationKinds,
                    onChanged: (next) =>
                        onChanged(_copyFilter(activationKinds: next)),
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
                      onChanged: (v) => onChanged(_copyFilter(freeText: v)),
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

  Filter _copyFilter({
    bool? onlyOngoing,
    bool? onlyLeaves,
    FilterContribution? contribution,
    List<String>? completionKinds,
    List<String>? activationKinds,
    String? freeText,
  }) {
    return Filter(
      ancestorGoalIds: filter.ancestorGoalIds,
      contribution: contribution ?? filter.contribution,
      completionKinds: completionKinds ?? filter.completionKinds,
      activationKinds: activationKinds ?? filter.activationKinds,
      onlyOngoing: onlyOngoing ?? filter.onlyOngoing,
      onlyLeaves: onlyLeaves ?? filter.onlyLeaves,
      freeText: freeText ?? filter.freeText,
    );
  }
}

class _ChipMultiSelect extends StatelessWidget {
  const _ChipMultiSelect({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

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
              for (final option in options)
                FilterChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: (isSelected) {
                    final next = [...selected];
                    if (isSelected) {
                      if (!next.contains(option)) next.add(option);
                    } else {
                      next.remove(option);
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
    required this.node,
    required this.depth,
    required this.now,
    required this.onToggleComplete,
    required this.onOpenDetail,
    required this.onQuickAddChild,
  });

  final Node node;
  final int depth;
  final DateTime now;
  final VoidCallback onToggleComplete;
  final VoidCallback onOpenDetail;
  final VoidCallback onQuickAddChild;

  static const double _indentPerLevel = 18;

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitleFor(node, now);
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: 12 + depth * _indentPerLevel,
        right: 4,
      ),
      leading: _leadingFor(context),
      title: Text(node.title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusBadge(node.status),
          IconButton(
            tooltip: 'Add child',
            icon: const Icon(Icons.add),
            visualDensity: VisualDensity.compact,
            onPressed: onQuickAddChild,
          ),
        ],
      ),
      onTap: onOpenDetail,
    );
  }

  /// Background goals (no completion concept) can never be "checked off", so
  /// a checkbox would be misleading. They show a goal icon instead;
  /// completion-bearing nodes get a real checkbox.
  Widget _leadingFor(BuildContext context) {
    if (node.status.completion == null) {
      return Icon(
        Icons.flag_outlined,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return Checkbox(
      value: !node.status.isOngoingAt(now),
      onChanged: (_) => onToggleComplete(),
    );
  }

  String? _subtitleFor(Node node, DateTime now) {
    final parts = <String>[];
    if (node.description != null && node.description!.isNotEmpty) {
      parts.add(node.description!);
    }
    if (node.deadline != null) {
      parts.add('Due ${_formatDate(node.deadline!)}');
    }
    final c = node.status.completion;
    if (c is NTimesCompletion) {
      parts.add('${c.remainingCount} of ${c.targetCount} left');
    } else if (c is PeriodicCompletion) {
      parts.add('Every ${c.intervalDaysSinceLastCompletion}d');
    }
    final a = node.status.activation;
    if (a is BoundedActive) {
      parts.add(
        'Active ${_formatDate(a.activeFrom)} – ${_formatDate(a.activeUntil)}',
      );
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

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
