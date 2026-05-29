import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/contribution.dart';
import '../model/filter.dart';
import '../widgets/node_picker.dart';

class FilterDrawer extends StatelessWidget {
  const FilterDrawer({
    super.key,
    required this.controller,
    required this.filter,
    required this.onChanged,
    required this.onSaveAsTile,
    this.showOnlyLeavesOption = true,
  });

  final GraphController controller;
  final Filter filter;
  final ValueChanged<Filter> onChanged;
  final Future<void> Function() onSaveAsTile;
  final bool showOnlyLeavesOption;

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
                  if (showOnlyLeavesOption)
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
    final parentIds = controller.graph.edges.map((e) => e.parentId).toSet();
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

Future<String?> promptForTileTitle(
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
  late final TextEditingController _controller = TextEditingController(
    text: widget.suggestion,
  );

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
        onSubmitted: (_) => Navigator.of(context).pop(_controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
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
