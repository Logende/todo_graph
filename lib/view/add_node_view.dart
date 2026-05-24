import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/contribution.dart';
import '../model/node_status.dart';

/// Form for creating a new node and linking it to an existing parent goal.
///
/// Defaults to one-time status because that's the most common task kind.
/// Periodic and N-times reveal their extra fields when selected.
class AddNodeView extends StatefulWidget {
  const AddNodeView({
    super.key,
    required this.controller,
    required this.defaultParentId,
  });

  final GraphController controller;
  final String defaultParentId;

  @override
  State<AddNodeView> createState() => _AddNodeViewState();
}

class _AddNodeViewState extends State<AddNodeView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priorityController = TextEditingController();
  final _impactController = TextEditingController();
  final _periodController = TextEditingController(text: '3');
  final _nTimesController = TextEditingController(text: '1');

  late String _parentId = widget.defaultParentId;
  StatusType _statusType = StatusType.oneTime;
  Contribution _contribution = Contribution.mandatory;
  DateTime? _deadline;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priorityController.dispose();
    _impactController.dispose();
    _periodController.dispose();
    _nTimesController.dispose();
    super.dispose();
  }

  NodeStatus _buildStatus() {
    return switch (_statusType) {
      StatusType.alwaysOn => const AlwaysOnStatus(),
      StatusType.oneTime => const OneTimeStatus(),
      StatusType.nTimes => NTimesStatus(
          targetCount: int.tryParse(_nTimesController.text) ?? 1,
        ),
      StatusType.periodic => PeriodicStatus(
          intervalDaysSinceLastCompletion:
              int.tryParse(_periodController.text) ?? 3,
        ),
      StatusType.temporarilyActive => TemporarilyActiveStatus(
          activeFrom: widget.controller.clock(),
          activeUntil:
              widget.controller.clock().add(const Duration(days: 30)),
        ),
    };
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.controller.addChildNode(
      title: _titleController.text.trim(),
      parentId: _parentId,
      status: _buildStatus(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      priority: double.tryParse(_priorityController.text),
      positiveImpact: double.tryParse(_impactController.text),
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
            const SizedBox(height: 16),
            DropdownButtonFormField<StatusType>(
              initialValue: _statusType,
              decoration: const InputDecoration(labelText: 'Status kind'),
              items: const [
                DropdownMenuItem(
                  value: StatusType.oneTime, child: Text('One-time')),
                DropdownMenuItem(
                  value: StatusType.alwaysOn, child: Text('Always on')),
                DropdownMenuItem(
                  value: StatusType.nTimes, child: Text('N times')),
                DropdownMenuItem(
                  value: StatusType.periodic, child: Text('Periodic')),
                DropdownMenuItem(
                  value: StatusType.temporarilyActive,
                  child: Text('Temporarily active'),
                ),
              ],
              onChanged: (v) => setState(() {
                if (v != null) _statusType = v;
              }),
            ),
            if (_statusType == StatusType.nTimes) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _nTimesController,
                decoration: const InputDecoration(labelText: 'Target count'),
                keyboardType: TextInputType.number,
              ),
            ],
            if (_statusType == StatusType.periodic) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _periodController,
                decoration: const InputDecoration(
                  labelText: 'Interval (days since last completion)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priorityController,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _impactController,
                    decoration: const InputDecoration(labelText: 'Impact'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
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
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: _pickDeadline,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final initial = _deadline ?? widget.controller.clock();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
