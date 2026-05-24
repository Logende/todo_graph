import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/activation_window.dart';
import '../model/completion.dart';
import '../model/filter.dart';
import '../model/node.dart';
import '../model/node_status.dart';
import '../service/filter_evaluator.dart';
import '../service/node_ordering.dart';
import 'add_node_view.dart';

/// View 2 from the spec: a flat, filtered, ordered list of tasks with
/// checkboxes for completion. This is the daily-use surface — the user lands
/// here by tapping a dashboard tile or via "All ongoing".
///
/// The view rebuilds whenever the [controller] notifies a change, so marking
/// a task complete (or any external change) immediately updates the list.
class TodoListView extends StatelessWidget {
  const TodoListView({
    super.key,
    required this.controller,
    required this.title,
    required this.filter,
    this.ordering = const NodeOrdering(),
    this.nowFactory,
  });

  final GraphController controller;
  final String title;
  final Filter filter;
  final NodeOrdering ordering;

  /// Injectable clock for tests. Defaults to wall clock.
  final DateTime Function()? nowFactory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final parentId = _addParentId(controller, filter);
          if (parentId == null) return const SizedBox.shrink();
          return FloatingActionButton(
            tooltip: 'Add task',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddNodeView(
                  controller: controller,
                  defaultParentId: parentId,
                ),
              ),
            ),
            child: const Icon(Icons.add),
          );
        },
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final now = (nowFactory ?? DateTime.now).call();
          final filtered = FilterEvaluator(
            graph: controller.graph,
            now: now,
          ).apply(filter);
          final ordered = ordering.defaultOrder(
            filtered,
            priorityPins: controller.graph.priorityPins,
          );

          if (ordered.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No tasks match this filter.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: ordered.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final node = ordered[index];
              return _NodeTile(
                node: node,
                now: now,
                onToggleComplete: () => controller.markCompleted(node.id),
              );
            },
          );
        },
      ),
    );
  }
}

/// Picks a sensible default parent for "Add task" from this view: the first
/// ancestor filter id if present, the configured root otherwise, or the
/// first graph node as a last resort.
String? _addParentId(GraphController controller, Filter filter) {
  if (filter.ancestorGoalIds.isNotEmpty) return filter.ancestorGoalIds.first;
  final configured = controller.graph.settings?.rootNodeId;
  if (configured != null) return configured;
  if (controller.graph.nodes.isNotEmpty) return controller.graph.nodes.first.id;
  return null;
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.now,
    required this.onToggleComplete,
  });

  final Node node;
  final DateTime now;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitleFor(node, now);
    final isOngoing = node.status.isOngoingAt(now);
    final hasCompletion = node.status.completion != null;
    return ListTile(
      leading: Checkbox(
        value: !isOngoing,
        onChanged: hasCompletion ? (_) => onToggleComplete() : null,
      ),
      title: Text(node.title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: _statusBadge(node.status),
    );
  }

  String? _subtitleFor(Node node, DateTime now) {
    final parts = <String>[];
    if (node.description != null && node.description!.isNotEmpty) {
      parts.add(node.description!);
    }
    if (node.deadline != null) {
      parts.add('Due ${_formatDate(node.deadline!)}');
    }
    final c = node.status.completion;
    if (c is NTimesCompletion) {
      parts.add('${c.remainingCount} of ${c.targetCount} left');
    } else if (c is PeriodicCompletion) {
      parts.add('Every ${c.intervalDaysSinceLastCompletion}d');
    }
    final a = node.status.activation;
    if (a is BoundedActive) {
      parts.add(
        'Active ${_formatDate(a.activeFrom)} – ${_formatDate(a.activeUntil)}',
      );
    }
    return parts.isEmpty ? null : parts.join(' • ');
  }

  Widget _statusBadge(NodeStatus status) {
    final completion = status.completion;
    final completionLabel = switch (completion) {
      null => 'goal',
      OneTimeCompletion() => '1×',
      NTimesCompletion() => '${completion.targetCount}×',
      PeriodicCompletion() => 'recurs',
    };
    final boundedSuffix = status.activation is BoundedActive ? ' · window' : '';
    return Chip(
      label: Text(
        '$completionLabel$boundedSuffix',
        style: const TextStyle(fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
