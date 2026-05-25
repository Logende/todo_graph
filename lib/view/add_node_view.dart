import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/activation_window.dart';
import '../model/completion.dart';
import '../model/contribution.dart';
import '../model/impact.dart';
import '../model/node_status.dart';
import 'status_form_enums.dart';
import '../widgets/node_picker.dart';

import 'view_helpers.dart';

/// Form for creating a new node and linking it to an existing parent goal.
///
/// Activation and completion are independent dropdowns, so the user can
/// express combinations like "active May 1 – Jun 1, must be done 3 times".
class AddNodeView extends StatefulWidget {
  const AddNodeView({
    super.key,
    required this.controller,
    required this.defaultParentId,
    this.initialTitle,
    this.initialStatus,
    this.initialContribution,
    this.initialImpact,
    this.initialDeadline,
  });

  final GraphController controller;
  final String defaultParentId;
  final String? initialTitle;
  final NodeStatus? initialStatus;
  final Contribution? initialContribution;
  final Impact? initialImpact;
  final DateTime? initialDeadline;

  @override
  State<AddNodeView> createState() => _AddNodeViewState();
}

class _AddNodeViewState extends State<AddNodeView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _periodController = TextEditingController(text: '3');
  final _nTimesController = TextEditingController(text: '1');

  late String _parentId = widget.defaultParentId;
  ActivationChoice _activation = ActivationChoice.alwaysActive;
  CompletionChoice _completion = CompletionChoice.oneTime;
  Contribution _contribution = Contribution.mandatory;
  Impact? _impact;
  DateTime? _deadline;
  DateTime? _activeFrom;
  DateTime? _activeUntil;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? '';
    _contribution = widget.initialContribution ?? Contribution.mandatory;
    _impact = widget.initialImpact;
    _deadline = widget.initialDeadline;
    final initialStatus = widget.initialStatus;
    if (initialStatus != null) {
      _activation = switch (initialStatus.activation) {
        AlwaysActive() => ActivationChoice.alwaysActive,
        BoundedActive() => ActivationChoice.bounded,
      };
      if (initialStatus.activation case final BoundedActive bounded) {
        _activeFrom = bounded.activeFrom;
        _activeUntil = bounded.activeUntil;
      }

      switch (initialStatus.completion) {
        case null:
          _completion = CompletionChoice.none;
        case OneTimeCompletion():
          _completion = CompletionChoice.oneTime;
        case NTimesCompletion(targetCount: final targetCount):
          _completion = CompletionChoice.nTimes;
          _nTimesController.text = '$targetCount';
        case PeriodicCompletion(
          intervalDaysSinceLastCompletion: final intervalDays,
        ):
          _completion = CompletionChoice.periodic;
          _periodController.text = '$intervalDays';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _periodController.dispose();
    _nTimesController.dispose();
    super.dispose();
  }

  ActivationWindow _buildActivation() {
    switch (_activation) {
      case ActivationChoice.alwaysActive:
        return const AlwaysActive();
      case ActivationChoice.bounded:
        // Either or both can be null — the model accepts open-ended windows.
        // When both are set, clamp so until >= from.
        final from = _activeFrom;
        final until = _activeUntil;
        if (from != null && until != null && until.isBefore(from)) {
          return BoundedActive(activeFrom: from, activeUntil: from);
        }
        return BoundedActive(activeFrom: from, activeUntil: until);
    }
  }

  Completion? _buildCompletion() {
    return switch (_completion) {
      CompletionChoice.none => null,
      CompletionChoice.oneTime => const OneTimeCompletion(),
      // validatePositiveInt has already gated the submit on these fields
      // being valid positive integers, so int.parse is safe here.
      CompletionChoice.nTimes => NTimesCompletion(
          targetCount: int.parse(_nTimesController.text),
        ),
      CompletionChoice.periodic => PeriodicCompletion(
          intervalDaysSinceLastCompletion: int.parse(_periodController.text),
        ),
    };
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final status = NodeStatus(
      activation: _buildActivation(),
      completion: _buildCompletion(),
    );
    widget.controller.addChildNode(
      title: _titleController.text.trim(),
      parentId: _parentId,
      status: status,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      impact: _impact,
      deadline: _deadline,
      contribution: _contribution,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = widget.controller.graph.nodes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New task'),
        actions: [
          TextButton(onPressed: _submit, child: const Text('Create')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Parent: ${nodes.firstWhere((n) => n.id == _parentId, orElse: () => nodes.first).title}',
              ),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () async {
                final picked = await showNodePicker(
                  context: context,
                  nodes: nodes,
                  title: 'Pick a parent goal',
                );
                if (picked != null) setState(() => _parentId = picked.id);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Contribution>(
              initialValue: _contribution,
              decoration: const InputDecoration(labelText: 'Contribution'),
              items: const [
                DropdownMenuItem(
                  value: Contribution.mandatory,
                  child: Text('Mandatory'),
                ),
                DropdownMenuItem(
                  value: Contribution.helpful,
                  child: Text('Helpful'),
                ),
              ],
              onChanged: (v) => setState(() {
                if (v != null) _contribution = v;
              }),
            ),
            const SizedBox(height: 24),
            Text('Activation',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<ActivationChoice>(
              initialValue: _activation,
              decoration:
                  const InputDecoration(labelText: 'When is this active'),
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
              const SizedBox(height: 12),
              _DatePickerRow(
                label: 'Active from (optional)',
                value: _activeFrom,
                onPick: (d) => setState(() {
                  _activeFrom = d;
                  if (_activeUntil != null && _activeUntil!.isBefore(d)) {
                    _activeUntil = d;
                  }
                }),
                onClear: () => setState(() => _activeFrom = null),
                contextClock: widget.controller.clock,
              ),
              const SizedBox(height: 8),
              _DatePickerRow(
                label: 'Active until (optional)',
                value: _activeUntil,
                onPick: (d) => setState(() => _activeUntil = d),
                onClear: () => setState(() => _activeUntil = null),
                contextClock: widget.controller.clock,
                minimumDate: _activeFrom,
              ),
            ],
            const SizedBox(height: 24),
            Text('Completion',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<CompletionChoice>(
              initialValue: _completion,
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _nTimesController,
                decoration: const InputDecoration(labelText: 'Target count'),
                keyboardType: TextInputType.number,
                validator: validatePositiveInt,
              ),
            ],
            if (_completion == CompletionChoice.periodic) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _periodController,
                decoration: const InputDecoration(
                  labelText: 'Interval (days since last completion)',
                ),
                keyboardType: TextInputType.number,
                validator: validatePositiveInt,
              ),
            ],
            const SizedBox(height: 24),
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
                    child: Text(impactLabel(level)),
                  ),
              ],
              onChanged: (v) => setState(() => _impact = v),
            ),
            const SizedBox(height: 16),
            _DatePickerRow(
              label: _deadline == null
                  ? 'No deadline'
                  : 'Deadline: ${formatDate(_deadline!)}',
              value: _deadline,
              onPick: (d) => setState(() => _deadline = d),
              onClear: () => setState(() => _deadline = null),
              contextClock: widget.controller.clock,
            ),
          ],
        ),
      ),
    );
  }
}

/// Display labels for the five impact levels. Kept here (not on the enum)
/// so the model has no UI concerns.


class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.contextClock,
    this.onClear,
    this.minimumDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final VoidCallback? onClear;
  final DateTime Function() contextClock;

  /// When provided, the picker rejects dates earlier than this — used to
  /// keep "Active until" >= "Active from".
  final DateTime? minimumDate;

  DateTime get _firstDate => minimumDate ?? DateTime(2020);

  DateTime get _initialDate {
    final candidate = value ?? contextClock();
    return candidate.isBefore(_firstDate) ? _firstDate : candidate;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(value == null ? label : '$label: ${formatDate(value!)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null && onClear != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: onClear,
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _initialDate,
                firstDate: _firstDate,
                lastDate: DateTime(2100),
              );
              if (picked != null) onPick(picked);
            },
          ),
        ],
      ),
    );
  }
}
