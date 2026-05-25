import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/graph_controller.dart';
import '../model/activation_window.dart';
import '../model/attachment.dart';
import '../model/completion.dart';
import '../model/edge.dart';
import '../model/impact.dart';
import '../model/node.dart';
import '../model/node_notification_settings.dart';
import '../model/node_relationship.dart';
import '../model/node_status.dart';
import '../service/external_url_opener.dart';
import '../service/node_queries.dart';
import '../widgets/node_picker.dart';

import 'view_helpers.dart';
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
    this.urlOpener = const ExternalUrlOpener(),
  });

  final GraphController controller;
  final String nodeId;
  final ExternalUrlOpener urlOpener;

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
          urlOpener: urlOpener,
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
    required this.urlOpener,
  });

  final GraphController controller;
  final Node node;
  final NodeQueries queries;
  final ExternalUrlOpener urlOpener;

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
          _SectionHeader(
            title: 'Attachments (${node.attachments.length})',
            trailing: PopupMenuButton<_AttachmentAction>(
              tooltip: 'Add attachment',
              onSelected: (action) => switch (action) {
                _AttachmentAction.url => _startAddUrlAttachment(context),
                _AttachmentAction.timeTrigger =>
                  _startAddTimeTriggerAttachment(context),
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _AttachmentAction.url,
                  child: Text('Add URL'),
                ),
                PopupMenuItem(
                  value: _AttachmentAction.timeTrigger,
                  child: Text('Add reminder time'),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_link),
                    SizedBox(width: 6),
                    Text('Add'),
                  ],
                ),
              ),
            ),
          ),
          if (node.attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No attachments. Paste an Obsidian URL '
                '(obsidian://open?vault=…) or any other link.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          for (final attachment in node.attachments.whereType<UrlAttachment>())
            _UrlAttachmentTile(
              attachment: attachment,
              onOpen: () => _openUrl(context, attachment.url),
              onCopy: () => _copyToClipboard(context, attachment.url),
              onRemove: () => _removeAttachment(attachment),
            ),
          for (final attachment
              in node.attachments.whereType<TimeTriggerAttachment>())
            _TimeTriggerAttachmentTile(
              attachment: attachment,
              onRemove: () => _removeAttachment(attachment),
            ),
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

  Future<void> _startAddUrlAttachment(BuildContext context) async {
    final result = await showDialog<_UrlAttachmentDraft>(
      context: context,
      builder: (_) => const _UrlAttachmentDialog(),
    );
    if (result == null) return;
    _addAttachment(UrlAttachment(url: result.url, label: result.label));
  }

  Future<void> _startAddTimeTriggerAttachment(BuildContext context) async {
    final attachment = await showDialog<TimeTriggerAttachment>(
      context: context,
      builder: (_) => const _TimeTriggerAttachmentDialog(),
    );
    if (attachment == null) return;
    _addAttachment(attachment);
  }

  void _addAttachment(Attachment attachment) {
    final updated = node.copyWith(
      attachments: [...node.attachments, attachment],
      updatedAt: controller.clock(),
    );
    controller.updateNode(updated);
  }

  void _removeAttachment(Attachment attachment) {
    final next = [...node.attachments]..remove(attachment);
    controller.updateNode(node.copyWith(
      attachments: next,
      updatedAt: controller.clock(),
    ));
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final error = await urlOpener.open(url);
    if (error == null || !context.mounted) return;
    await _showUrlError(context, error);
  }

  Future<void> _showUrlError(BuildContext context, String body) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Could not open URL'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final updated = await showDialog<Node>(
      context: context,
      builder: (_) => _NodeEditorDialog(
        initial: node,
        clock: controller.clock,
      ),
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
      lines.add('Deadline: ${formatDate(node.deadline!)}');
    } else if (inheritedDeadline != null) {
      lines.add('Deadline: ${formatDate(inheritedDeadline)} (inherited)');
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
  const _NodeEditorDialog({required this.initial, required this.clock});
  final Node initial;
  final DateTime Function() clock;

  @override
  State<_NodeEditorDialog> createState() => _NodeEditorDialogState();
}

class _NodeEditorDialogState extends State<_NodeEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController =
      TextEditingController(text: widget.initial.title);
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initial.description ?? '');
  late final TextEditingController _nTimesController =
      TextEditingController(text: _initialTargetCount.toString());
  late final TextEditingController _periodController =
      TextEditingController(text: _initialIntervalDays.toString());
  late final TextEditingController _leadTimeController = TextEditingController(
    text: widget.initial.notificationOverride?.deadlineLeadTimeHours
            ?.toString() ??
        '',
  );
  late bool? _notifyOnReopen =
      widget.initial.notificationOverride?.notifyOnPeriodicReopen;

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
    _leadTimeController.dispose();
    super.dispose();
  }

  /// Builds the NodeNotificationSettings from the current form state, or
  /// returns null when both axes are 'use global default' so we don't
  /// persist an empty override object.
  NodeNotificationSettings? _buildNotificationOverride() {
    final leadTimeText = _leadTimeController.text.trim();
    final leadTime = leadTimeText.isEmpty ? null : int.tryParse(leadTimeText);
    if (leadTime == null && _notifyOnReopen == null) return null;
    return NodeNotificationSettings(
      deadlineLeadTimeHours: leadTime,
      notifyOnPeriodicReopen: _notifyOnReopen,
    );
  }

  ActivationWindow _buildActivation(DateTime now) {
    switch (_activation) {
      case _ActivationChoice.alwaysActive:
        return const AlwaysActive();
      case _ActivationChoice.bounded:
        final from = _activeFrom;
        final until = _activeUntil;
        if (from != null && until != null && until.isBefore(from)) {
          return BoundedActive(activeFrom: from, activeUntil: from);
        }
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
        // The form validator gates submit on this being a positive int.
        final target = int.parse(_nTimesController.text);
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
        final days = int.parse(_periodController.text);
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

  String? _validateOptionalPositiveInt(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return validatePositiveInt(trimmed);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final title = _titleController.text.trim();
    final now = widget.clock();
    final description = _descriptionController.text.trim();
    final status = NodeStatus(
      activation: _buildActivation(now),
      completion: _buildCompletion(),
    );
    final override = _buildNotificationOverride();
    final updated = widget.initial.copyWith(
      title: title,
      description: description.isEmpty ? null : description,
      clearDescription: description.isEmpty,
      status: status,
      impact: _impact,
      clearImpact: _impact == null,
      deadline: _deadline,
      clearDeadline: _deadline == null,
      notificationOverride: override,
      clearNotificationOverride: override == null,
      updatedAt: now,
    );
    Navigator.of(context).pop(updated);
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? widget.clock(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _pickActiveFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _activeFrom ?? widget.clock(),
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
    final initial = _activeUntil ?? _activeFrom ?? widget.clock();
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
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
                  isExpanded: true,
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
                        : 'Active from: ${formatDate(_activeFrom!)}',
                    onPick: _pickActiveFrom,
                  ),
                  _DateRow(
                    label: _activeUntil == null
                        ? 'Active until'
                        : 'Active until: ${formatDate(_activeUntil!)}',
                    onPick: _pickActiveUntil,
                  ),
                ],
                const SizedBox(height: 20),
                _SectionLabel('Completion'),
                DropdownButtonFormField<_CompletionChoice>(
                  initialValue: _completion,
                  isExpanded: true,
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
                  TextFormField(
                    controller: _nTimesController,
                    decoration:
                        const InputDecoration(labelText: 'Target count'),
                    keyboardType: TextInputType.number,
                    validator: validatePositiveInt,
                  ),
                ],
                if (_completion == _CompletionChoice.periodic) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _periodController,
                    decoration: const InputDecoration(
                      labelText: 'Interval (days since last completion)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: validatePositiveInt,
                  ),
                ],
                const SizedBox(height: 20),
                _SectionLabel('Notifications'),
                TextFormField(
                  controller: _leadTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Deadline reminder lead time (hours)',
                    helperText: 'Leave blank to use the global default',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateOptionalPositiveInt,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<bool?>(
                  initialValue: _notifyOnReopen,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Periodic reopen notifications',
                  ),
                  items: const [
                    DropdownMenuItem<bool?>(
                      value: null,
                      child: Text('Use global default'),
                    ),
                    DropdownMenuItem<bool?>(
                      value: true,
                      child: Text('Always notify'),
                    ),
                    DropdownMenuItem<bool?>(
                      value: false,
                      child: Text('Do not notify'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _notifyOnReopen = v),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<Impact?>(
                  initialValue: _impact,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Impact'),
                  items: [
                    const DropdownMenuItem<Impact?>(
                      child: Text('— not set —'),
                    ),
                    for (final level in Impact.values)
                      DropdownMenuItem<Impact?>(
                        value: level,
                        child: Text(impactLabel(level)),
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
                        : 'Deadline: ${formatDate(_deadline!)}',
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

/// One row per [UrlAttachment]. Tap the title or the open icon to launch the
/// URL through the OS — `obsidian://` schemes go to Obsidian when it's
/// installed, https links to the default browser, etc.
class _UrlAttachmentTile extends StatelessWidget {
  const _UrlAttachmentTile({
    required this.attachment,
    required this.onOpen,
    required this.onCopy,
    required this.onRemove,
  });

  final UrlAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onRemove;

  bool get _isObsidian => attachment.url.startsWith('obsidian://');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        _isObsidian ? Icons.book_outlined : Icons.link,
        color: scheme.primary,
      ),
      title: Text(
        attachment.label ?? attachment.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: attachment.label == null
          ? null
          : Text(
              attachment.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Open URL',
            icon: const Icon(Icons.open_in_new),
            onPressed: onOpen,
          ),
          IconButton(
            tooltip: 'Copy URL',
            icon: const Icon(Icons.copy_outlined),
            onPressed: onCopy,
          ),
          IconButton(
            tooltip: 'Remove attachment',
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
      onTap: onOpen,
    );
  }
}

class _TimeTriggerAttachmentTile extends StatelessWidget {
  const _TimeTriggerAttachmentTile({
    required this.attachment,
    required this.onRemove,
  });

  final TimeTriggerAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.alarm_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(attachment.label ?? 'Reminder'),
      subtitle: Text('Triggers at ${formatDateTime(attachment.triggerAt)}'),
      trailing: IconButton(
        tooltip: 'Remove attachment',
        icon: const Icon(Icons.close),
        onPressed: onRemove,
      ),
    );
  }
}

enum _AttachmentAction { url, timeTrigger }

class _UrlAttachmentDraft {
  const _UrlAttachmentDraft({required this.url, this.label});

  final String url;
  final String? label;
}

/// Paste-in dialog for a URL attachment. Accepts any URI with a non-empty
/// scheme so the user can use http(s), mailto, obsidian:// etc.
class _UrlAttachmentDialog extends StatefulWidget {
  const _UrlAttachmentDialog();

  @override
  State<_UrlAttachmentDialog> createState() => _UrlAttachmentDialogState();
}

class _UrlAttachmentDialogState extends State<_UrlAttachmentDialog> {
  final _urlController = TextEditingController();
  final _labelController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Paste a URL first');
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.isEmpty) {
      setState(() => _error =
          'Not a valid URL — needs a scheme like https:// or obsidian://');
      return;
    }
    final label = _labelController.text.trim();
    Navigator.of(context).pop(
      _UrlAttachmentDraft(
        url: raw,
        label: label.isEmpty ? null : label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Attach a URL'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText:
                    'obsidian://open?vault=…&file=…  or  https://example.com',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Obsidian URLs open the linked note in Obsidian when it is '
              'installed locally and the vault is mounted.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Attach')),
      ],
    );
  }
}

class _TimeTriggerAttachmentDialog extends StatefulWidget {
  const _TimeTriggerAttachmentDialog();

  @override
  State<_TimeTriggerAttachmentDialog> createState() =>
      _TimeTriggerAttachmentDialogState();
}

class _TimeTriggerAttachmentDialogState
    extends State<_TimeTriggerAttachmentDialog> {
  final _labelController = TextEditingController();
  late DateTime _triggerAt = DateTime.now().add(const Duration(hours: 1));

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _triggerAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _triggerAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _triggerAt.hour,
        _triggerAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_triggerAt),
    );
    if (picked == null) return;
    setState(() {
      _triggerAt = DateTime(
        _triggerAt.year,
        _triggerAt.month,
        _triggerAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _submit() {
    final label = _labelController.text.trim();
    Navigator.of(context).pop(
      TimeTriggerAttachment(
        triggerAt: _triggerAt,
        label: label.isEmpty ? null : label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add reminder time'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _labelController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g. Ping Peter if not done',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text('Date: ${formatDate(_triggerAt)}'),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(
                'Time: ${_triggerAt.hour.toString().padLeft(2, '0')}:${_triggerAt.minute.toString().padLeft(2, '0')}',
              ),
              onTap: _pickTime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Attach'),
        ),
      ],
    );
  }
}



