import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/activation_window.dart';
import '../model/completion.dart';
import '../model/contribution.dart';
import '../model/filter.dart';
import '../model/node.dart';
import '../model/node_status.dart';
import '../model/settings.dart';
import '../service/filter_evaluator.dart';
import '../service/graph_traversal.dart';
import '../service/hierarchical_ordering.dart';
import '../service/node_queries.dart';
import '../theme/layout.dart';
import '../widgets/node_picker.dart';
import 'add_node_view.dart';
import 'node_detail_view.dart';
import 'quick_add_child_dialog.dart';
import 'view_helpers.dart';

class TaskListPane extends StatefulWidget {
  const TaskListPane({
    super.key,
    required this.controller,
    required this.filter,
    this.nowFactory,
  });

  final GraphController controller;
  final Filter filter;
  final DateTime Function()? nowFactory;

  @override
  State<TaskListPane> createState() => _TaskListPaneState();
}

class _TaskListPaneState extends State<TaskListPane> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final now = (widget.nowFactory ?? widget.controller.clock).call();
        final queries = NodeQueries(widget.controller.graph);
        final isTreeMode = !widget.filter.onlyLeaves;
        final filtered = FilterEvaluator(
          graph: widget.controller.graph,
          now: now,
        ).apply(widget.filter);
        final urgentWindowDays =
            widget.controller.graph.settings?.effectiveUrgentWindowDays ??
            kDefaultUrgentWindowDays;
        final fullHierarchy =
            HierarchicalOrdering(
              urgentWindow: Duration(days: urgentWindowDays),
            ).arrange(
              nodes: filtered,
              edges: widget.controller.graph.edges,
              relationships: widget.controller.graph.relationships,
              now: now,
            );
        final collapsedNodeIds =
            widget.controller.graph.settings?.collapsedNodeIds.toSet() ??
            const <String>{};
        final hierarchy = isTreeMode
            ? _applyCollapsedRows(
                fullHierarchy,
                collapsedNodeIds: collapsedNodeIds,
              )
            : fullHierarchy;
        final expandablePathIds = isTreeMode
            ? _expandablePathIds(fullHierarchy)
            : const <String>{};

        if (hierarchy.isEmpty) {
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

        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: hierarchy.length,
          onReorderItem: (oldIndex, newIndex) =>
              _handleReorder(hierarchy, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final row = hierarchy[index];
            final parentId = _parentIdFromPath(row.pathId);
            final edgeContribution = parentId == null
                ? null
                : widget.controller.graph.edges
                      .where(
                        (e) =>
                            e.childId == row.node.id && e.parentId == parentId,
                      )
                      .firstOrNull
                      ?.contribution;
            return _TaskListTile(
              key: ValueKey('row-${row.pathId}'),
              index: index,
              node: row.node,
              depth: row.depth,
              now: now,
              queries: queries,
              currentParentId: parentId,
              edgeContribution: edgeContribution,
              isTreeMode: isTreeMode,
              isCollapsed: collapsedNodeIds.contains(row.node.id),
              isExpandable: expandablePathIds.contains(row.pathId),
              onToggleCollapsed: () => _toggleCollapsed(row.node.id),
              onMoveToParent: (currentParentId) =>
                  _moveNodeToParent(row.node, currentParentId),
              onSetCompleted: (isCompleted) =>
                  _setCompletedWithUndo(row.node, isCompleted: isCompleted),
              onOpenDetail: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NodeDetailView(
                    controller: widget.controller,
                    nodeId: row.node.id,
                  ),
                ),
              ),
              onQuickAddChild: () => _startQuickAddChild(row.node),
            );
          },
        );
      },
    );
  }

  void _setCompletedWithUndo(Node node, {required bool isCompleted}) {
    widget.controller.setCompleted(node.id, isCompleted: isCompleted);
    final message = isCompleted
        ? '"${node.title}" completed'
        : '"${node.title}" reopened';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: kUndoSnackBarDuration,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => widget.controller.setCompleted(
              node.id,
              isCompleted: !isCompleted,
            ),
          ),
        ),
      );
  }

  void _toggleCollapsed(String nodeId) {
    final current =
        widget.controller.graph.settings?.collapsedNodeIds.toSet() ??
        <String>{};
    if (!current.add(nodeId)) {
      current.remove(nodeId);
    }
    widget.controller.setCollapsedNodeIds(current.toList()..sort());
  }

  Future<void> _moveNodeToParent(Node node, String? currentParentId) async {
    if (currentParentId == null) return;
    final traversal = GraphTraversal(widget.controller.graph);
    final excluded = <String>{node.id, ...traversal.descendantsOf(node.id)};
    final target = await showNodePicker(
      context: context,
      nodes: widget.controller.graph.nodes,
      excludeIds: excluded,
      title: 'Move "${node.title}" under…',
    );
    if (target == null) return;
    widget.controller.moveNodeToParent(
      childId: node.id,
      fromParentId: currentParentId,
      toParentId: target.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved "${node.title}" under "${target.title}"')),
    );
  }

  void _handleReorder(
    List<HierarchicalRow> hierarchy,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex == oldIndex) return;

    final moved = hierarchy[oldIndex];
    final movingUp = newIndex < oldIndex;
    final crossed = <HierarchicalRow>[];
    final step = movingUp ? -1 : 1;
    for (
      var i = oldIndex + step;
      movingUp ? i >= newIndex : i <= newIndex;
      i += step
    ) {
      crossed.add(hierarchy[i]);
    }

    final crossedSiblings = crossed
        .where(
          (r) =>
              r.depth == moved.depth && _sameParentPath(r.pathId, moved.pathId),
        )
        .toList(growable: false);
    final crossedNonSiblings = crossed.length - crossedSiblings.length;

    if (crossedNonSiblings > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only siblings under the same parent can be reordered.',
          ),
        ),
      );
      return;
    }
    if (crossedSiblings.isEmpty) return;

    for (final sibling in crossedSiblings) {
      if (movingUp) {
        widget.controller.setMoreImportantThan(
          higherId: moved.node.id,
          lowerId: sibling.node.id,
        );
      } else {
        widget.controller.setMoreImportantThan(
          higherId: sibling.node.id,
          lowerId: moved.node.id,
        );
      }
    }
  }

  bool _sameParentPath(String pathA, String pathB) {
    final aSlash = pathA.lastIndexOf('>');
    final bSlash = pathB.lastIndexOf('>');
    if (aSlash != bSlash) return false;
    if (aSlash < 0) return true;
    return pathA.substring(0, aSlash) == pathB.substring(0, bSlash);
  }

  Future<void> _startQuickAddChild(Node parent) async {
    final result = await showQuickAddChild(
      context: context,
      parentTitle: parent.title,
    );
    if (result == null) return;
    if (result is QuickAddSubmission) {
      widget.controller.addChildNode(
        title: result.title,
        parentId: parent.id,
        status: result.status,
        impact: result.impact,
        deadline: result.deadline,
        contribution: result.contribution,
      );
      return;
    }
    if (result is QuickAddEscalation && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AddNodeView(
            controller: widget.controller,
            defaultParentId: parent.id,
            initialTitle: result.title,
            initialStatus: result.status,
            initialContribution: result.contribution,
            initialImpact: result.impact,
            initialDeadline: result.deadline,
          ),
        ),
      );
    }
  }
}

class _TaskListTile extends StatelessWidget {
  const _TaskListTile({
    super.key,
    required this.index,
    required this.node,
    required this.depth,
    required this.now,
    required this.queries,
    required this.currentParentId,
    required this.edgeContribution,
    required this.isTreeMode,
    required this.isCollapsed,
    required this.isExpandable,
    required this.onToggleCollapsed,
    required this.onMoveToParent,
    required this.onSetCompleted,
    required this.onOpenDetail,
    required this.onQuickAddChild,
  });

  final int index;
  final Node node;
  final int depth;
  final DateTime now;
  final NodeQueries queries;
  final String? currentParentId;
  final Contribution? edgeContribution;
  final bool isTreeMode;
  final bool isCollapsed;
  final bool isExpandable;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<String?> onMoveToParent;
  final ValueChanged<bool> onSetCompleted;
  final VoidCallback onOpenDetail;
  final VoidCallback onQuickAddChild;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < kNarrowScreenBreakpoint;
    final subtitle = _subtitleFor(node, now, isNarrow: isNarrow);
    final scheme = Theme.of(context).colorScheme;
    final indentPerLevel = isNarrow
        ? kIndentPerLevelNarrow
        : kIndentPerLevelWide;
    final effectiveDepth = depth.clamp(0, kMaxDisplayDepth);
    final borderColor = switch (edgeContribution) {
      Contribution.mandatory => scheme.primary,
      Contribution.helpful => scheme.outlineVariant,
      null => Colors.transparent,
    };
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: edgeContribution != null ? kContributionBorderWidth : 0,
            ),
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.only(
            left: 4 + effectiveDepth * indentPerLevel,
            right: 4,
          ),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTreeMode)
                SizedBox(
                  width: isNarrow ? 24 : 28,
                  child: isExpandable
                      ? IconButton(
                          tooltip: isCollapsed
                              ? 'Expand child tasks'
                              : 'Collapse child tasks',
                          icon: Icon(
                            isCollapsed
                                ? Icons.chevron_right
                                : Icons.expand_more,
                            size: isNarrow
                                ? kCompactIconSize
                                : kDefaultIconSize,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onToggleCollapsed,
                        )
                      : const SizedBox.shrink(),
                ),
              if (!isNarrow)
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: 'Drag to reorder among siblings',
                    child: Icon(
                      Icons.drag_indicator,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              if (!isNarrow) const SizedBox(width: 4),
              _leadingFor(context, isNarrow: isNarrow),
            ],
          ),
          title: Text(
            node.title,
            maxLines: isNarrow ? 2 : null,
            overflow: isNarrow ? TextOverflow.ellipsis : null,
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  maxLines: isNarrow ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isNarrow) _statusBadge(node.status),
              if (isTreeMode && currentParentId != null && !isNarrow)
                IconButton(
                  tooltip: 'Move to another parent',
                  icon: const Icon(Icons.drive_file_move_outline),
                  visualDensity: VisualDensity.compact,
                  iconSize: isNarrow ? kCompactIconSize : kDefaultIconSize,
                  onPressed: () => onMoveToParent(currentParentId),
                ),
              IconButton(
                tooltip: 'Add child',
                icon: const Icon(Icons.add),
                visualDensity: VisualDensity.compact,
                iconSize: isNarrow ? kCompactIconSize : kDefaultIconSize,
                onPressed: onQuickAddChild,
              ),
            ],
          ),
          onTap: onOpenDetail,
        ),
      ),
    );
  }

  Widget _leadingFor(BuildContext context, {required bool isNarrow}) {
    final iconSize = isNarrow ? kCompactIconSize : kDefaultIconSize;
    if (node.status.completion == null) {
      return Icon(
        Icons.flag_outlined,
        size: iconSize,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    final activation = node.status.activation;
    if (activation is BoundedActive &&
        activation.activeFrom != null &&
        now.isBefore(activation.activeFrom!)) {
      return Tooltip(
        message: 'Not active yet',
        child: Icon(
          Icons.schedule_outlined,
          size: iconSize,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    final blockedByChildren = queries
        .openMandatoryChildrenOf(node.id, now)
        .isNotEmpty;
    if (blockedByChildren) {
      return Tooltip(
        message: 'Mandatory child tasks still open',
        child: Icon(
          Icons.lock_outline,
          size: iconSize,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    return Checkbox(
      visualDensity: isNarrow ? VisualDensity.compact : VisualDensity.standard,
      value: !node.status.isOngoingAt(now),
      onChanged: (value) {
        if (value != null) onSetCompleted(value);
      },
    );
  }

  String? _subtitleFor(Node node, DateTime now, {required bool isNarrow}) {
    final parts = <String>[];
    if (node.description != null && node.description!.isNotEmpty) {
      parts.add(node.description!);
    }
    final inheritedDeadline = queries.inheritedDeadline(node.id);
    if (node.deadline != null) {
      parts.add('Due ${formatDate(node.deadline!)}');
    } else if (inheritedDeadline != null) {
      final suffix = isNarrow ? '' : ' (inherited)';
      parts.add('Due ${formatDate(inheritedDeadline)}$suffix');
    }
    final c = node.status.completion;
    if (c is NTimesCompletion) {
      parts.add('${c.remainingCount} of ${c.targetCount} left');
    } else if (c is PeriodicCompletion) {
      parts.add('Every ${c.intervalDaysSinceLastCompletion}d');
    }
    if (!isNarrow) {
      final a = node.status.activation;
      if (a is BoundedActive) {
        final fromLabel = a.activeFrom != null
            ? formatDate(a.activeFrom!)
            : '…';
        final untilLabel = a.activeUntil != null
            ? formatDate(a.activeUntil!)
            : '…';
        parts.add('Active $fromLabel – $untilLabel');
      }
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
}

List<HierarchicalRow> _applyCollapsedRows(
  List<HierarchicalRow> rows, {
  required Set<String> collapsedNodeIds,
}) {
  if (rows.isEmpty || collapsedNodeIds.isEmpty) return rows;
  final visible = <HierarchicalRow>[];
  final collapsedPrefixes = <String>[];
  for (final row in rows) {
    collapsedPrefixes.removeWhere(
      (prefix) => !_isDescendantPath(row.pathId, prefix),
    );
    if (collapsedPrefixes.isNotEmpty) continue;
    visible.add(row);
    if (collapsedNodeIds.contains(row.node.id)) {
      collapsedPrefixes.add(row.pathId);
    }
  }
  return visible;
}

Set<String> _expandablePathIds(List<HierarchicalRow> rows) {
  final out = <String>{};
  for (var i = 0; i < rows.length - 1; i++) {
    if (rows[i + 1].depth > rows[i].depth) out.add(rows[i].pathId);
  }
  return out;
}

bool _isDescendantPath(String path, String ancestorPath) =>
    path.startsWith('$ancestorPath>');

String? _parentIdFromPath(String pathId) {
  final parts = pathId.split('>');
  if (parts.length < 2) return null;
  return parts[parts.length - 2];
}
