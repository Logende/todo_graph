import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/activation_window.dart';
import '../model/completion.dart';
import '../model/contribution.dart';
import '../model/impact.dart';
import '../model/node_status.dart';

/// UI selectors for the activation axis.
enum _ActivationChoice { alwaysActive, bounded }

/// UI selectors for the completion axis. `none` means "background goal".
enum _CompletionChoice { none, oneTime, nTimes, periodic }

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
  });

  final GraphController controller;
  final String defaultParentId;
  final String? initialTitle;
  final NodeStatus? initialStatus;

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
  _ActivationChoice _activation = _ActivationChoice.alwaysActive;
  _CompletionChoice _completion = _CompletionChoice.oneTime;
  Contribution _contribution = Contribution.mandatory;
  Impact? _impact;
  DateTime? _deadline;
  DateTime? _activeFrom;
  DateTime? _activeUntil;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? '';
    final initialStatus = widget.initialStatus;
    if (initialStatus != null) {
      _activation = switch (initialStatus.activation) {
        AlwaysActive() => _ActivationChoice.alwaysActive,
        BoundedActive() => _ActivationChoice.bounded,
      };
      if (initialStatus.activation case final BoundedActive bounded) {
        _activeFrom = bounded.activeFrom;
        _activeUntil = bounded.activeUntil;
      }

      switch (initialStatus.completion) {
        case null:
          _completion = _CompletionChoice.none;
        case OneTimeCompletion():
          _completion = _CompletionChoice.oneTime;
        case NTimesCompletion(targetCount: final targetCount):
          _completion = _CompletionChoice.nTimes;
          _nTimesController.text = '$targetCount';
        case PeriodicCompletion(
          intervalDaysSinceLastCompletion: final intervalDays,
        ):
          _completion = _CompletionChoice.periodic;
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
      case _ActivationChoice.alwaysActive:
        return const AlwaysActive();
      case _ActivationChoice.bounded:
        final from = _activeFrom ?? widget.controller.clock();
        final defaultUntil = from.add(const Duration(days: 30));
        final picked = _activeUntil ?? defaultUntil;
        // Defensive clamp — the UI prevents picking an earlier "until", but
        // if anything slips through (e.g. clearing then re-entering bounded
        // mode) we'd rather snap the window than throw at submit time.
        final until = picked.isBefore(from) ? from : picked;
        return BoundedActive(activeFrom: from, activeUntil: until);
    }
  }

  Completion? _buildCompletion() {
    return switch (_completion) {
      _CompletionChoice.none => null,
      _CompletionChoice.oneTime => const OneTimeCompletion(),
      _CompletionChoice.nTimes => NTimesCompletion(
          targetCount: int.tryParse(_nTimesController.text) ?? 1,
        ),
      _CompletionChoice.periodic => PeriodicCompletion(
          intervalDaysSinceLastCompletion:
              int.tryParse(_periodController.text) ?? 3,
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
            DropdownButtonFormField<String>(
              initialValue: _parentId,
              decoration: const InputDecoration(labelText: 'Parent goal'),
              items: [
                for (final n in nodes)
                  DropdownMenuItem(value: n.id, child: Text(n.title)),
              ],
              onChanged: (v) => setState(() {
                if (v != null) _parentId = v;
              }),
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
            DropdownButtonFormField<_ActivationChoice>(
              initialValue: _activation,
              decoration:
                  const InputDecoration(labelText: 'When is this active'),
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
              const SizedBox(height: 12),
              _DatePickerRow(
                label: 'Active from',
                value: _activeFrom,
                onPick: (d) => setState(() {
                  _activeFrom = d;
                  // Keep the window valid: pull "until" forward if the new
                  // "from" landed past it.
                  if (_activeUntil != null && _activeUntil!.isBefore(d)) {
                    _activeUntil = d;
                  }
                }),
                contextClock: widget.controller.clock,
              ),
              const SizedBox(height: 8),
              _DatePickerRow(
                label: 'Active until',
                value: _activeUntil,
                onPick: (d) => setState(() => _activeUntil = d),
                contextClock: widget.controller.clock,
                minimumDate: _activeFrom,
              ),
            ],
            const SizedBox(height: 24),
            Text('Completion',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _nTimesController,
                decoration: const InputDecoration(labelText: 'Target count'),
                keyboardType: TextInputType.number,
              ),
            ],
            if (_completion == _CompletionChoice.periodic) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _periodController,
                decoration: const InputDecoration(
                  labelText: 'Interval (days since last completion)',
                ),
                keyboardType: TextInputType.number,
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
                    child: Text(_impactLabel(level)),
                  ),
              ],
              onChanged: (v) => setState(() => _impact = v),
            ),
            const SizedBox(height: 16),
            _DatePickerRow(
              label: _deadline == null
                  ? 'No deadline'
                  : 'Deadline: ${_formatDate(_deadline!)}',
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
      title: Text(value == null ? label : '$label: ${_formatDate(value!)}'),
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
