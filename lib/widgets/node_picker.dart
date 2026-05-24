import 'package:flutter/material.dart';

import '../model/node.dart';

/// Modal dialog that lets the user pick a node by free-text search.
///
/// Opens via [showNodePicker]. Returns the chosen [Node] or null if the user
/// dismisses without picking. Use [excludeIds] to drop ineligible candidates
/// (e.g. the current node when picking a relationship target).
Future<Node?> showNodePicker({
  required BuildContext context,
  required List<Node> nodes,
  Set<String> excludeIds = const {},
  String title = 'Pick a node',
}) {
  final candidates =
      nodes.where((n) => !excludeIds.contains(n.id)).toList(growable: false);
  return showDialog<Node>(
    context: context,
    builder: (_) => NodePickerDialog(title: title, candidates: candidates),
  );
}

@visibleForTesting
class NodePickerDialog extends StatefulWidget {
  const NodePickerDialog({
    super.key,
    required this.title,
    required this.candidates,
  });

  final String title;
  final List<Node> candidates;

  @override
  State<NodePickerDialog> createState() => _NodePickerDialogState();
}

class _NodePickerDialogState extends State<NodePickerDialog> {
  String _query = '';

  List<Node> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.candidates;
    return widget.candidates
        .where((n) => n.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        height: 360,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter by title',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('No matching nodes'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final node = matches[index];
                        return ListTile(
                          title: Text(node.title),
                          onTap: () => Navigator.of(context).pop(node),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
