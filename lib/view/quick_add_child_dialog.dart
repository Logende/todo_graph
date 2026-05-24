import 'package:flutter/material.dart';

import '../model/node_status.dart';

/// Streamlined "Add child" form. Title-only by default, with a small status
/// picker and an "Open full form" escape hatch for the rare case where the
/// user needs to set deadline, impact, attachments, etc.
///
/// Returns:
/// * `null` when the user cancels.
/// * a [QuickAddSubmission] when the user submits via Add.
/// * [QuickAddEscalation.instance] when the user wants the full editor.
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
  const QuickAddSubmission({required this.title, required this.status});
  final String title;
  final NodeStatus status;
}

class QuickAddEscalation extends QuickAddResult {
  const QuickAddEscalation._();
  static const QuickAddEscalation instance = QuickAddEscalation._();
}

class _QuickAddChildDialog extends StatefulWidget {
  const _QuickAddChildDialog({required this.parentTitle});
  final String parentTitle;

  @override
  State<_QuickAddChildDialog> createState() => _QuickAddChildDialogState();
}

enum _QuickStatusChoice { oneTime, periodicThreeDays, background }

class _QuickAddChildDialogState extends State<_QuickAddChildDialog> {
  final _controller = TextEditingController();
  _QuickStatusChoice _choice = _QuickStatusChoice.oneTime;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  NodeStatus _buildStatus() => switch (_choice) {
        _QuickStatusChoice.oneTime => NodeStatus.oneTime(),
        _QuickStatusChoice.periodicThreeDays =>
          NodeStatus.periodic(intervalDaysSinceLastCompletion: 3),
        _QuickStatusChoice.background => NodeStatus.alwaysOnBackground,
      };

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context)
        .pop(QuickAddSubmission(title: title, status: _buildStatus()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add child of "${widget.parentTitle}"'),
      content: SizedBox(
        width: 360,
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(QuickAddEscalation.instance),
          child: const Text('More options…'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

String _choiceLabel(_QuickStatusChoice choice) => switch (choice) {
      _QuickStatusChoice.oneTime => 'One-time',
      _QuickStatusChoice.periodicThreeDays => 'Every 3 days',
      _QuickStatusChoice.background => 'Background goal',
    };
