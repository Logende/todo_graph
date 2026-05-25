import 'package:flutter/material.dart';

import '../model/contribution.dart';
import '../model/impact.dart';
import '../model/node_status.dart';

import 'view_helpers.dart';
/// Streamlined "Add child" form. Title-only by default, with a small status
/// picker and an "Open full form" escape hatch for the rare case where the
/// user needs to set deadline, impact, attachments, etc.
///
/// Returns:
/// * `null` when the user cancels.
/// * a [QuickAddSubmission] when the user submits via Add.
/// * a [QuickAddEscalation] when the user wants the full editor, preserving
///   the draft title and status they already chose.
Future<QuickAddResult?> showQuickAddChild({
  required BuildContext context,
  required String parentTitle,
}) async {
  return showDialog<QuickAddResult>(
    context: context,
    builder: (_) => _QuickAddChildDialog(parentTitle: parentTitle),
  );
}

sealed class QuickAddResult {
  const QuickAddResult();
}

class QuickAddSubmission extends QuickAddResult {
  const QuickAddSubmission({
    required this.title,
    required this.status,
    required this.contribution,
    required this.impact,
    required this.deadline,
  });
  final String title;
  final NodeStatus status;
  final Contribution contribution;
  final Impact? impact;
  final DateTime? deadline;
}

class QuickAddEscalation extends QuickAddResult {
  const QuickAddEscalation({
    required this.title,
    required this.status,
    required this.contribution,
    required this.impact,
    required this.deadline,
  });
  final String title;
  final NodeStatus status;
  final Contribution contribution;
  final Impact? impact;
  final DateTime? deadline;
}

class _QuickAddChildDialog extends StatefulWidget {
  const _QuickAddChildDialog({required this.parentTitle});
  final String parentTitle;

  @override
  State<_QuickAddChildDialog> createState() => _QuickAddChildDialogState();
}

enum _QuickStatusChoice { oneTime, daily, everyThreeDays, weekly, background }

class _QuickAddChildDialogState extends State<_QuickAddChildDialog> {
  final _controller = TextEditingController();
  _QuickStatusChoice _choice = _QuickStatusChoice.oneTime;
  Contribution _contribution = Contribution.mandatory;
  Impact? _impact;
  DateTime? _deadline;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  NodeStatus _buildStatus() => switch (_choice) {
        _QuickStatusChoice.oneTime => NodeStatus.oneTime(),
        _QuickStatusChoice.daily =>
          NodeStatus.periodic(intervalDaysSinceLastCompletion: 1),
        _QuickStatusChoice.everyThreeDays =>
          NodeStatus.periodic(intervalDaysSinceLastCompletion: 3),
        _QuickStatusChoice.weekly =>
          NodeStatus.periodic(intervalDaysSinceLastCompletion: 7),
        _QuickStatusChoice.background => NodeStatus.alwaysOnBackground,
      };

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(QuickAddSubmission(
      title: title,
      status: _buildStatus(),
      contribution: _contribution,
      impact: _impact,
      deadline: _deadline,
    ));
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add child of "${widget.parentTitle}"'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in _QuickStatusChoice.values)
                  ChoiceChip(
                    label: Text(_choiceLabel(entry)),
                    selected: _choice == entry,
                    onSelected: (_) => setState(() => _choice = entry),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<Contribution>(
              segments: const [
                ButtonSegment(
                  value: Contribution.mandatory,
                  label: Text('Mandatory'),
                ),
                ButtonSegment(
                  value: Contribution.helpful,
                  label: Text('Helpful'),
                ),
              ],
              selected: {_contribution},
              onSelectionChanged: (selection) => setState(() {
                _contribution = selection.first;
              }),
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
                    child: Text(impactLabel(level)),
                  ),
              ],
              onChanged: (v) => setState(() => _impact = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _deadline == null
                        ? 'No deadline'
                        : 'Deadline: ${formatDate(_deadline!)}',
                  ),
                ),
                TextButton(
                  onPressed: _pickDeadline,
                  child: Text(_deadline == null ? 'Pick deadline' : 'Change'),
                ),
                if (_deadline != null)
                  IconButton(
                    tooltip: 'Clear deadline',
                    onPressed: () => setState(() => _deadline = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            QuickAddEscalation(
              title: _controller.text,
              status: _buildStatus(),
              contribution: _contribution,
              impact: _impact,
              deadline: _deadline,
            ),
          ),
          child: const Text('More options…'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

String _choiceLabel(_QuickStatusChoice choice) => switch (choice) {
      _QuickStatusChoice.oneTime => 'One-time',
      _QuickStatusChoice.daily => 'Daily',
      _QuickStatusChoice.everyThreeDays => 'Every 3 days',
      _QuickStatusChoice.weekly => 'Weekly',
      _QuickStatusChoice.background => 'Background goal',
    };


