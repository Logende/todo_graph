import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/edge.dart';
import '../model/impact.dart';
import '../model/node.dart';
import '../model/node_relationship.dart';
import '../service/node_queries.dart';
import '../widgets/node_picker.dart';

/// Inspector for a single node: shows its description and status, lists its
/// parent edges and its non-structural relationships with remove actions,
/// and exposes "Add relationship" and "Delete node" actions.
///
/// Rebuilds whenever the controller notifies, so external changes (or this
/// view's own mutations) flow through immediately.
class NodeDetailView extends StatelessWidget {
  const NodeDetailView({
    super.key,
    required this.controller,
    required this.nodeId,
  });

  final GraphController controller;
  final String nodeId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final node = controller.graph.nodes
            .where((n) => n.id == nodeId)
            .firstOrNull;
        if (node == null) {
          // The node was deleted out from under us — bounce back.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return _DetailScaffold(
          controller: controller,
          node: node,
          queries: NodeQueries(controller.graph),
        );
      },
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.controller,
    required this.node,
    required this.queries,
  });

  final GraphController controller;
  final Node node;
  final NodeQueries queries;

  @override
  Widget build(BuildContext context) {
    final parentEdges =
        controller.graph.edges.where((e) => e.childId == node.id).toList();
    final relationships = controller.graph.relationships
        .where((r) => r.fromNodeId == node.id || r.toNodeId == node.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(node.title),
        actions: [
          IconButton(
            tooltip: 'Edit node',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openEditor(context),
          ),
          IconButton(
            tooltip: 'Delete this node',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (node.description != null && node.description!.isNotEmpty) ...[
            Text(node.description!),
            const SizedBox(height: 16),
          ],
          _StatusSummary(node: node, queries: queries),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Parents (${parentEdges.length})'),
          ...parentEdges.map((e) => _ParentTile(
                edge: e,
                parentTitle: _titleForId(e.parentId),
                onRemove: () => controller.removeEdge(e.id),
              )),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Relationships (${relationships.length})',
            trailing: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              onPressed: () => _startAddRelationship(context),
            ),
          ),
          if (relationships.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No importance or alternative links yet.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ...relationships.map((r) => _RelationshipTile(
                relationship: r,
                fromTitle: _titleForId(r.fromNodeId),
                toTitle: _titleForId(r.toNodeId),
                onRemove: () => controller.removeRelationship(r.id),
              )),
        ],
      ),
    );
  }

  String _titleForId(String id) {
    final match = controller.graph.nodes.where((n) => n.id == id).firstOrNull;
    return match?.title ?? '(missing node $id)';
  }

  Future<void> _openEditor(BuildContext context) async {
    final updated = await showDialog<Node>(
      context: context,
      builder: (_) => _NodeEditorDialog(initial: node),
    );
    if (updated == null) return;
    controller.updateNode(updated);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this node?'),
        content: Text(
          'Removes "${node.title}" and every edge and relationship that '
          'references it. This cannot be undone.',
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
    // The node will be removed by deleteNode; the build's "node was deleted"
    // branch then pops this route on the next frame. Don't pop explicitly
    // here or we double-pop and unwind past the caller's screen.
    controller.deleteNode(node.id);
  }

  Future<void> _startAddRelationship(BuildContext context) async {
    final kind = await _pickRelationshipKind(context);
    if (kind == null || !context.mounted) return;

    final target = await showNodePicker(
      context: context,
      nodes: controller.graph.nodes,
      excludeIds: {node.id},
      title: 'Target of $node.title – ${_kindLabel(kind)}',
    );
    if (target == null) return;

    controller.addRelationship(
      fromNodeId: node.id,
      toNodeId: target.id,
      kind: kind,
    );
  }

  Future<RelationshipKind?> _pickRelationshipKind(BuildContext context) {
    return showDialog<RelationshipKind>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Relationship kind'),
        children: [
          for (final kind in RelationshipKind.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(kind),
              child: Text(_kindLabel(kind)),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.node, required this.queries});

  final Node node;
  final NodeQueries queries;

  @override
  Widget build(BuildContext context) {
    final activationLabel =
        'Activation: ${_activationLabelFor(node)}';
    final completionLabel =
        'Completion: ${_completionLabelFor(node)}';
    final lines = <String>[activationLabel, completionLabel];
    final inheritedDeadline = queries.inheritedDeadline(node.id);
    if (node.deadline != null) {
      lines.add('Deadline: ${_formatDate(node.deadline!)}');
    } else if (inheritedDeadline != null) {
      lines.add('Deadline: ${_formatDate(inheritedDeadline)} (inherited)');
    }
    if (node.impact != null) {
      lines.add('Impact: ${node.impact!.name}');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in lines) Text(line)],
        ),
      ),
    );
  }

  String _activationLabelFor(Node node) {
    final activation = node.status.activation;
    return switch (activation.kind) {
      'bounded' => 'bounded window',
      _ => 'always active',
    };
  }

  String _completionLabelFor(Node node) {
    final c = node.status.completion;
    if (c == null) return 'background goal (no completion)';
    return c.kind;
  }

  String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

class _ParentTile extends StatelessWidget {
  const _ParentTile({
    required this.edge,
    required this.parentTitle,
    required this.onRemove,
  });

  final Edge edge;
  final String parentTitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.arrow_upward),
      title: Text(parentTitle),
      subtitle: Text(edge.contribution.name),
      trailing: IconButton(
        icon: const Icon(Icons.link_off),
        tooltip: 'Remove this parent link',
        onPressed: onRemove,
      ),
    );
  }
}

class _RelationshipTile extends StatelessWidget {
  const _RelationshipTile({
    required this.relationship,
    required this.fromTitle,
    required this.toTitle,
    required this.onRemove,
  });

  final NodeRelationship relationship;
  final String fromTitle;
  final String toTitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconFor(relationship.kind)),
      title: Text(_describe(relationship, fromTitle, toTitle)),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Remove this relationship',
        onPressed: onRemove,
      ),
    );
  }
}

String _kindLabel(RelationshipKind kind) => switch (kind) {
      RelationshipKind.moreImportantThan => 'More important than',
      RelationshipKind.lessImportantThan => 'Less important than',
      RelationshipKind.alternativeTo => 'Alternative to',
    };

IconData _iconFor(RelationshipKind kind) => switch (kind) {
      RelationshipKind.moreImportantThan => Icons.arrow_upward,
      RelationshipKind.lessImportantThan => Icons.arrow_downward,
      RelationshipKind.alternativeTo => Icons.swap_horiz,
    };

String _describe(
  NodeRelationship relationship,
  String fromTitle,
  String toTitle,
) {
  return '$fromTitle  ${_arrowFor(relationship.kind)}  $toTitle';
}

String _arrowFor(RelationshipKind kind) => switch (kind) {
      RelationshipKind.moreImportantThan => '>',
      RelationshipKind.lessImportantThan => '<',
      RelationshipKind.alternativeTo => '~',
    };

/// In-place editor for a node's intrinsic fields. Scoped to the values the
/// detail screen surfaces: title, description, impact, deadline. Activation
/// + completion semantics stay where they were created (use AddNodeView for
/// new shapes).
class _NodeEditorDialog extends StatefulWidget {
  const _NodeEditorDialog({required this.initial});
  final Node initial;

  @override
  State<_NodeEditorDialog> createState() => _NodeEditorDialogState();
}

class _NodeEditorDialogState extends State<_NodeEditorDialog> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.initial.title);
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initial.description ?? '');
  late Impact? _impact = widget.initial.impact;
  late DateTime? _deadline = widget.initial.deadline;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final description = _descriptionController.text.trim();
    final updated = widget.initial.copyWith(
      title: title,
      description: description.isEmpty ? null : description,
      clearDescription: description.isEmpty,
      impact: _impact,
      clearImpact: _impact == null,
      deadline: _deadline,
      clearDeadline: _deadline == null,
      updatedAt: DateTime.now(),
    );
    Navigator.of(context).pop(updated);
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit node'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Impact?>(
                initialValue: _impact,
                decoration: const InputDecoration(labelText: 'Impact'),
                items: [
                  const DropdownMenuItem<Impact?>(
                    child: Text('— not set —'),
                  ),
                  for (final level in Impact.values)
                    DropdownMenuItem<Impact?>(
                      value: level,
                      child: Text(_impactLabel(level)),
                    ),
                ],
                onChanged: (v) => setState(() => _impact = v),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _deadline == null
                      ? 'No deadline'
                      : 'Deadline: ${_formatDate(_deadline!)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_deadline != null)
                      IconButton(
                        tooltip: 'Clear deadline',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _deadline = null),
                      ),
                    IconButton(
                      tooltip: 'Pick deadline',
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: _pickDeadline,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

String _impactLabel(Impact level) => switch (level) {
      Impact.minimal => 'Minimal',
      Impact.low => 'Low',
      Impact.medium => 'Medium',
      Impact.high => 'High',
      Impact.critical => 'Critical',
    };

String _formatDate(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';
