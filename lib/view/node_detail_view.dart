import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/activation_window.dart';
import '../model/completion.dart';
import '../model/edge.dart';
import '../model/impact.dart';
import '../model/node.dart';
import '../model/node_relationship.dart';
import '../model/node_status.dart';
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
    final choice = await _pickLinkKind(context);
    if (choice == null || !context.mounted) return;

    final target = await showNodePicker(
      context: context,
      nodes: controller.graph.nodes,
      excludeIds: {node.id},
      title: '${_linkLabel(choice)} — pick the other node',
    );
    if (target == null) return;

    try {
      switch (choice) {
        case _AddLinkChoice.dependsOn:
          // "This depends on target" → target is a (mandatory) prerequisite
          // child of this node.
          controller.addEdge(childId: target.id, parentId: node.id);
        case _AddLinkChoice.dependentOf:
          // "This is a dependent of target" → this node is a (mandatory)
          // child of target. Adds an extra parent for the current node.
          controller.addEdge(childId: node.id, parentId: target.id);
        case _AddLinkChoice.moreImportantThan:
          controller.addRelationship(
            fromNodeId: node.id,
            toNodeId: target.id,
            kind: RelationshipKind.moreImportantThan,
          );
        case _AddLinkChoice.lessImportantThan:
          controller.addRelationship(
            fromNodeId: node.id,
            toNodeId: target.id,
            kind: RelationshipKind.lessImportantThan,
          );
        case _AddLinkChoice.alternativeTo:
          controller.addRelationship(
            fromNodeId: node.id,
            toNodeId: target.id,
            kind: RelationshipKind.alternativeTo,
          );
      }
    } on StateError catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Could not add link'),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    // ArgumentError from the mutator (unknown id / duplicate id) is treated
    // as a programmer error and lets the framework surface it.
    // Contribution defaults to mandatory; future iteration can offer
    // 'helpful' as a second-step choice for the depends-on edges.
  }

  Future<_AddLinkChoice?> _pickLinkKind(BuildContext context) {
    return showDialog<_AddLinkChoice>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Link to another node'),
        children: [
          for (final choice in _AddLinkChoice.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(choice),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(_linkIcon(choice)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_linkLabel(choice)),
                          Text(
                            _linkExplanation(choice),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Choices in the "Add link" dialog. The first two map to structural edges
/// (parent/child), the rest to NodeRelationships.
enum _AddLinkChoice {
  dependsOn,
  dependentOf,
  moreImportantThan,
  lessImportantThan,
  alternativeTo,
}

String _linkLabel(_AddLinkChoice choice) => switch (choice) {
      _AddLinkChoice.dependsOn => 'Depends on…',
      _AddLinkChoice.dependentOf => 'Is a dependent of…',
      _AddLinkChoice.moreImportantThan => 'More important than…',
      _AddLinkChoice.lessImportantThan => 'Less important than…',
      _AddLinkChoice.alternativeTo => 'Alternative to…',
    };

String _linkExplanation(_AddLinkChoice choice) => switch (choice) {
      _AddLinkChoice.dependsOn =>
        'The other node becomes a prerequisite — added as a child of this one.',
      _AddLinkChoice.dependentOf =>
        'This node becomes a child of the other — that other node depends on this.',
      _AddLinkChoice.moreImportantThan =>
        'Ranks this node above the other in the default ordering.',
      _AddLinkChoice.lessImportantThan =>
        'Ranks this node below the other in the default ordering.',
      _AddLinkChoice.alternativeTo =>
        'Marks them as equivalent — closing one closes the other.',
    };

IconData _linkIcon(_AddLinkChoice choice) => switch (choice) {
      _AddLinkChoice.dependsOn => Icons.subdirectory_arrow_right,
      _AddLinkChoice.dependentOf => Icons.subdirectory_arrow_left,
      _AddLinkChoice.moreImportantThan => Icons.arrow_upward,
      _AddLinkChoice.lessImportantThan => Icons.arrow_downward,
      _AddLinkChoice.alternativeTo => Icons.swap_horiz,
    };

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

enum _ActivationChoice { alwaysActive, bounded }

enum _CompletionChoice { none, oneTime, nTimes, periodic }

/// Full in-place editor for every intrinsic property of a node: title,
/// description, activation window, completion semantics, impact, deadline.
/// Returns the edited [Node] via Navigator.pop, or null on cancel.
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
  late final TextEditingController _nTimesController =
      TextEditingController(text: _initialTargetCount.toString());
  late final TextEditingController _periodController =
      TextEditingController(text: _initialIntervalDays.toString());

  late Impact? _impact = widget.initial.impact;
  late DateTime? _deadline = widget.initial.deadline;

  late _ActivationChoice _activation = _initialActivationChoice;
  late _CompletionChoice _completion = _initialCompletionChoice;
  late DateTime? _activeFrom = _initialActiveFrom;
  late DateTime? _activeUntil = _initialActiveUntil;

  _ActivationChoice get _initialActivationChoice {
    final activation = widget.initial.status.activation;
    return activation is BoundedActive
        ? _ActivationChoice.bounded
        : _ActivationChoice.alwaysActive;
  }

  DateTime? get _initialActiveFrom {
    final activation = widget.initial.status.activation;
    return activation is BoundedActive ? activation.activeFrom : null;
  }

  DateTime? get _initialActiveUntil {
    final activation = widget.initial.status.activation;
    return activation is BoundedActive ? activation.activeUntil : null;
  }

  _CompletionChoice get _initialCompletionChoice {
    final completion = widget.initial.status.completion;
    return switch (completion) {
      null => _CompletionChoice.none,
      OneTimeCompletion() => _CompletionChoice.oneTime,
      NTimesCompletion() => _CompletionChoice.nTimes,
      PeriodicCompletion() => _CompletionChoice.periodic,
    };
  }

  int get _initialTargetCount {
    final completion = widget.initial.status.completion;
    return completion is NTimesCompletion ? completion.targetCount : 1;
  }

  int get _initialIntervalDays {
    final completion = widget.initial.status.completion;
    return completion is PeriodicCompletion
        ? completion.intervalDaysSinceLastCompletion
        : 3;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _nTimesController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  ActivationWindow _buildActivation(DateTime now) {
    switch (_activation) {
      case _ActivationChoice.alwaysActive:
        return const AlwaysActive();
      case _ActivationChoice.bounded:
        final from = _activeFrom ?? now;
        final defaultUntil = from.add(const Duration(days: 30));
        final picked = _activeUntil ?? defaultUntil;
        // Defensive clamp matches AddNodeView's behaviour.
        final until = picked.isBefore(from) ? from : picked;
        return BoundedActive(activeFrom: from, activeUntil: until);
    }
  }

  Completion? _buildCompletion() {
    switch (_completion) {
      case _CompletionChoice.none:
        return null;
      case _CompletionChoice.oneTime:
        // Preserve a pre-existing completion timestamp so editing other
        // properties of an already-completed task doesn't reopen it.
        final existing = widget.initial.status.completion;
        if (existing is OneTimeCompletion) return existing;
        return const OneTimeCompletion();
      case _CompletionChoice.nTimes:
        final target = int.tryParse(_nTimesController.text) ?? 1;
        final existing = widget.initial.status.completion;
        final completedCount =
            existing is NTimesCompletion ? existing.completedCount : 0;
        final lastCompletedAt =
            existing is NTimesCompletion ? existing.lastCompletedAt : null;
        return NTimesCompletion(
          targetCount: target,
          completedCount: completedCount.clamp(0, target),
          lastCompletedAt: lastCompletedAt,
        );
      case _CompletionChoice.periodic:
        final days = int.tryParse(_periodController.text) ?? 3;
        final existing = widget.initial.status.completion;
        final lastCompletedAt = existing is PeriodicCompletion
            ? existing.lastCompletedAt
            : null;
        return PeriodicCompletion(
          intervalDaysSinceLastCompletion: days,
          lastCompletedAt: lastCompletedAt,
        );
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final now = DateTime.now();
    final description = _descriptionController.text.trim();
    final status = NodeStatus(
      activation: _buildActivation(now),
      completion: _buildCompletion(),
    );
    final updated = widget.initial.copyWith(
      title: title,
      description: description.isEmpty ? null : description,
      clearDescription: description.isEmpty,
      status: status,
      impact: _impact,
      clearImpact: _impact == null,
      deadline: _deadline,
      clearDeadline: _deadline == null,
      updatedAt: now,
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

  Future<void> _pickActiveFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _activeFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _activeFrom = picked;
      // Keep the window valid.
      if (_activeUntil != null && _activeUntil!.isBefore(picked)) {
        _activeUntil = picked;
      }
    });
  }

  Future<void> _pickActiveUntil() async {
    final minimum = _activeFrom ?? DateTime(2020);
    final initial = _activeUntil ?? _activeFrom ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(minimum) ? minimum : initial,
      firstDate: minimum,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _activeUntil = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit node'),
      content: SizedBox(
        width: 440,
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
              const SizedBox(height: 20),
              _SectionLabel('Activation'),
              DropdownButtonFormField<_ActivationChoice>(
                initialValue: _activation,
                decoration: const InputDecoration(
                  labelText: 'When is this active',
                ),
                items: const [
                  DropdownMenuItem(
                    value: _ActivationChoice.alwaysActive,
                    child: Text('Always active'),
                  ),
                  DropdownMenuItem(
                    value: _ActivationChoice.bounded,
                    child: Text('Only during a time window'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  if (v != null) _activation = v;
                }),
              ),
              if (_activation == _ActivationChoice.bounded) ...[
                const SizedBox(height: 8),
                _DateRow(
                  label: _activeFrom == null
                      ? 'Active from'
                      : 'Active from: ${_formatDate(_activeFrom!)}',
                  onPick: _pickActiveFrom,
                ),
                _DateRow(
                  label: _activeUntil == null
                      ? 'Active until'
                      : 'Active until: ${_formatDate(_activeUntil!)}',
                  onPick: _pickActiveUntil,
                ),
              ],
              const SizedBox(height: 20),
              _SectionLabel('Completion'),
              DropdownButtonFormField<_CompletionChoice>(
                initialValue: _completion,
                decoration: const InputDecoration(
                  labelText: 'How is this completed',
                ),
                items: const [
                  DropdownMenuItem(
                    value: _CompletionChoice.oneTime,
                    child: Text('Once (one-shot)'),
                  ),
                  DropdownMenuItem(
                    value: _CompletionChoice.nTimes,
                    child: Text('A fixed number of times'),
                  ),
                  DropdownMenuItem(
                    value: _CompletionChoice.periodic,
                    child: Text('Recurring (period from last completion)'),
                  ),
                  DropdownMenuItem(
                    value: _CompletionChoice.none,
                    child: Text('Background goal (no completion)'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  if (v != null) _completion = v;
                }),
              ),
              if (_completion == _CompletionChoice.nTimes) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _nTimesController,
                  decoration:
                      const InputDecoration(labelText: 'Target count'),
                  keyboardType: TextInputType.number,
                ),
              ],
              if (_completion == _CompletionChoice.periodic) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _periodController,
                  decoration: const InputDecoration(
                    labelText: 'Interval (days since last completion)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 20),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.onPick});
  final String label;
  final VoidCallback onPick;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today_outlined),
        onPressed: onPick,
      ),
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
