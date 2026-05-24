import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/filter_preset.dart';

/// Screen for renaming, deleting, and reordering the saved dashboard tiles.
/// Opened from Settings → 'Manage saved tiles'.
///
/// Reorder is via drag-handle (matches the per-row drag pattern used in the
/// todo lists). Each row also has a rename + delete action.
class ManagePresetsView extends StatelessWidget {
  const ManagePresetsView({super.key, required this.controller});

  final GraphController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage saved tiles')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final presets = controller.graph.filterPresets;
          if (presets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No saved tiles yet. Open any list, set up a filter, and '
                  'use "Save as tile" to create one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: presets.length,
            onReorderItem: (oldIndex, newIndex) =>
                _handleReorder(presets, oldIndex, newIndex),
            itemBuilder: (context, index) => _PresetRow(
              key: ValueKey('preset-${presets[index].id}'),
              index: index,
              preset: presets[index],
              onRename: () => _rename(context, presets[index]),
              onDelete: () => _delete(context, presets[index]),
            ),
          );
        },
      ),
    );
  }

  void _handleReorder(
    List<FilterPreset> presets,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex == oldIndex) return;
    final moved = presets[oldIndex];
    final next = [...presets]..removeAt(oldIndex);
    next.insert(newIndex, moved);
    // Renumber the ordering field so the dashboard reflects the new order
    // even after a reload.
    final renumbered = [
      for (var i = 0; i < next.length; i++)
        FilterPreset(
          id: next[i].id,
          title: next[i].title,
          filter: next[i].filter,
          iconName: next[i].iconName,
          ordering: i,
        ),
    ];
    controller.setFilterPresets(renumbered);
  }

  Future<void> _rename(BuildContext context, FilterPreset preset) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialTitle: preset.title),
    );
    if (result == null || result.isEmpty || result == preset.title) return;
    final next = controller.graph.filterPresets
        .map((p) => p.id == preset.id
            ? FilterPreset(
                id: p.id,
                title: result,
                filter: p.filter,
                iconName: p.iconName,
                ordering: p.ordering,
              )
            : p)
        .toList(growable: false);
    controller.setFilterPresets(next);
  }

  Future<void> _delete(BuildContext context, FilterPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this tile?'),
        content: Text(
          'Removes the "${preset.title}" tile from the dashboard. The '
          'underlying tasks are not touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final next =
        controller.graph.filterPresets.where((p) => p.id != preset.id).toList();
    controller.setFilterPresets(next);
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    super.key,
    required this.index,
    required this.preset,
    required this.onRename,
    required this.onDelete,
  });

  final int index;
  final FilterPreset preset;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: Tooltip(
          message: 'Drag to reorder',
          child: Icon(
            Icons.drag_indicator,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      title: Text(preset.title),
      subtitle: Text(_describeFilter(preset)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onRename,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _describeFilter(FilterPreset preset) {
    final parts = <String>[];
    final f = preset.filter;
    if (f.onlyOngoing) parts.add('ongoing');
    if (f.onlyLeaves) parts.add('leaves');
    if (f.ancestorGoalIds.isNotEmpty) {
      parts.add('under ${f.ancestorGoalIds.length} goal'
          '${f.ancestorGoalIds.length == 1 ? '' : 's'}');
    }
    if (f.completionKinds.isNotEmpty) {
      parts.add(f.completionKinds.join('/'));
    }
    if (f.freeText != null && f.freeText!.isNotEmpty) {
      parts.add('text: ${f.freeText}');
    }
    return parts.isEmpty ? 'No filter' : parts.join(' · ');
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialTitle});
  final String initialTitle;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialTitle);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename tile'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Tile title'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
