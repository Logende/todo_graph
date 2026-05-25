import 'package:flutter/material.dart';

import '../model/activation_window.dart';
import '../model/completion.dart';
import '../model/impact.dart';
import '../model/node.dart';
import '../model/node_notification_settings.dart';
import '../model/node_status.dart';
import 'status_form_enums.dart';
import 'view_helpers.dart';

/// Full in-place editor for every intrinsic property of a node: title,
/// description, activation window, completion semantics, notifications,
/// impact, deadline. Returns the edited [Node] via Navigator.pop, or null
/// on cancel.
///
/// Extracted from node_detail_view.dart so that file stays focused on the
/// read-only inspector and action hub.
class NodeEditorDialog extends StatefulWidget {
  const NodeEditorDialog({super.key, required this.initial, required this.clock});
  final Node initial;
  final DateTime Function() clock;

  @override
  State<NodeEditorDialog> createState() => _NodeEditorDialogState();
}

class _NodeEditorDialogState extends State<NodeEditorDialog> {
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

  late ActivationChoice _activation = _initialActivationChoice;
  late CompletionChoice _completion = _initialCompletionChoice;
  late DateTime? _activeFrom = _initialActiveFrom;
  late DateTime? _activeUntil = _initialActiveUntil;

  ActivationChoice get _initialActivationChoice {
    final activation = widget.initial.status.activation;
    return activation is BoundedActive
        ? ActivationChoice.bounded
        : ActivationChoice.alwaysActive;
  }

  DateTime? get _initialActiveFrom {
    final activation = widget.initial.status.activation;
    return activation is BoundedActive ? activation.activeFrom : null;
  }

  DateTime? get _initialActiveUntil {
    final activation = widget.initial.status.activation;
    return activation is BoundedActive ? activation.activeUntil : null;
  }

  CompletionChoice get _initialCompletionChoice {
    final completion = widget.initial.status.completion;
    return switch (completion) {
      null => CompletionChoice.none,
      OneTimeCompletion() => CompletionChoice.oneTime,
      NTimesCompletion() => CompletionChoice.nTimes,
      PeriodicCompletion() => CompletionChoice.periodic,
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
      case ActivationChoice.alwaysActive:
        return const AlwaysActive();
      case ActivationChoice.bounded:
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
      case CompletionChoice.none:
        return null;
      case CompletionChoice.oneTime:
        final existing = widget.initial.status.completion;
        if (existing is OneTimeCompletion) return existing;
        return const OneTimeCompletion();
      case CompletionChoice.nTimes:
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
      case CompletionChoice.periodic:
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
                DropdownButtonFormField<ActivationChoice>(
                  initialValue: _activation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'When is this active',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ActivationChoice.alwaysActive,
                      child: Text('Always active'),
                    ),
                    DropdownMenuItem(
                      value: ActivationChoice.bounded,
                      child: Text('Only during a time window'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    if (v != null) _activation = v;
                  }),
                ),
                if (_activation == ActivationChoice.bounded) ...[
                  const SizedBox(height: 8),
                  _DateRow(
                    label: _activeFrom == null
                        ? 'Active from (optional)'
                        : 'Active from: ${formatDate(_activeFrom!)}',
                    onPick: _pickActiveFrom,
                  ),
                  _DateRow(
                    label: _activeUntil == null
                        ? 'Active until (optional)'
                        : 'Active until: ${formatDate(_activeUntil!)}',
                    onPick: _pickActiveUntil,
                  ),
                ],
                const SizedBox(height: 20),
                _SectionLabel('Completion'),
                DropdownButtonFormField<CompletionChoice>(
                  initialValue: _completion,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'How is this completed',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: CompletionChoice.oneTime,
                      child: Text('Once (one-shot)'),
                    ),
                    DropdownMenuItem(
                      value: CompletionChoice.nTimes,
                      child: Text('A fixed number of times'),
                    ),
                    DropdownMenuItem(
                      value: CompletionChoice.periodic,
                      child: Text('Recurring (period from last completion)'),
                    ),
                    DropdownMenuItem(
                      value: CompletionChoice.none,
                      child: Text('Background goal (no completion)'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    if (v != null) _completion = v;
                  }),
                ),
                if (_completion == CompletionChoice.nTimes) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nTimesController,
                    decoration:
                        const InputDecoration(labelText: 'Target count'),
                    keyboardType: TextInputType.number,
                    validator: validatePositiveInt,
                  ),
                ],
                if (_completion == CompletionChoice.periodic) ...[
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
