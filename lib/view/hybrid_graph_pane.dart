import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/graph_controller.dart';
import '../model/activation_window.dart';
import '../model/completion.dart';
import '../model/contribution.dart';
import '../model/edge.dart';
import '../model/filter.dart';
import '../model/filter_preset.dart';
import '../model/impact.dart';
import '../model/node.dart';
import '../model/node_relationship.dart';
import '../service/filter_evaluator.dart';
import '../service/graph_traversal.dart';
import '../service/node_ordering.dart';
import '../service/node_queries.dart';
import '../theme/layout.dart';
import 'add_node_view.dart';
import 'node_detail_view.dart';
import 'quick_add_child_dialog.dart';
import 'view_helpers.dart';

/// Snapshot of the graph's level structure, reported back to the shell so it
/// can render the current level in the app-bar title.
class HybridGraphLevelInfo {
  const HybridGraphLevelInfo({
    required this.focusedLevel,
    required this.levelCount,
    required this.focusedLevelLabel,
  });

  static const empty = HybridGraphLevelInfo(
    focusedLevel: 0,
    levelCount: 0,
    focusedLevelLabel: null,
  );

  final int focusedLevel;
  final int levelCount;
  final String? focusedLevelLabel;

  @override
  bool operator ==(Object other) =>
      other is HybridGraphLevelInfo &&
      other.focusedLevel == focusedLevel &&
      other.levelCount == levelCount &&
      other.focusedLevelLabel == focusedLevelLabel;

  @override
  int get hashCode => Object.hash(focusedLevel, levelCount, focusedLevelLabel);
}

/// Imperative handle the shell uses to drive the graph pane's viewport from
/// app-bar buttons. Attach it to a [HybridGraphPane] via its `paneController`.
class HybridGraphPaneController {
  _HybridGraphPaneState? _state;

  void _attach(_HybridGraphPaneState state) => _state = state;

  void _detach(_HybridGraphPaneState state) {
    if (identical(_state, state)) _state = null;
  }

  void previousLevel() => _state?._stepLevel(-1);

  void nextLevel() => _state?._stepLevel(1);

  void zoomIn() => _state?._changeZoom(1.16);

  void zoomOut() => _state?._changeZoom(0.86);

  void fitCurrentLevel() => _state?._fitCurrentLevel();

  /// Re-fits the first level. Used after the filter changes so the view snaps
  /// back to the leaves instead of leaving the previous scroll position.
  void resetToFirstLevel() => _state?._scheduleFocus(0, preserveZoom: false);

  /// Re-centers on the current level while preserving zoom. Used after a
  /// layout-affecting toggle such as parent placement.
  void refocusCurrentLevel() =>
      _state?._scheduleFocus(null, preserveZoom: true);
}

/// The graph rendering for the task explorer: a column-per-level Sugiyama-style
/// layout inside an [InteractiveViewer]. Owns its own viewport, focused level,
/// and node interactions; the surrounding shell ([HybridHierarchyView]) owns
/// the filter, display mode, and app-bar chrome.
class HybridGraphPane extends StatefulWidget {
  const HybridGraphPane({
    super.key,
    required this.controller,
    required this.filter,
    required this.graphFlow,
    required this.centerParents,
    required this.onLevelInfoChanged,
    this.paneController,
  });

  final GraphController controller;
  final Filter filter;
  final ExplorerGraphFlow graphFlow;
  final bool centerParents;
  final ValueChanged<HybridGraphLevelInfo> onLevelInfoChanged;
  final HybridGraphPaneController? paneController;

  @override
  State<HybridGraphPane> createState() => _HybridGraphPaneState();
}

class _HybridGraphPaneState extends State<HybridGraphPane> {
  final _viewport = TransformationController();
  int _focusedLevel = 0;
  Size _lastViewportSize = Size.zero;
  EdgeInsets _lastSceneInsets = EdgeInsets.zero;
  _HybridLayout? _lastLayout;
  HybridGraphLevelInfo? _lastReported;

  _HierarchyFlow get _flow => _flowFromSettings(widget.graphFlow);

  @override
  void initState() {
    super.initState();
    widget.paneController?._attach(this);
  }

  @override
  void didUpdateWidget(HybridGraphPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.paneController, widget.paneController)) {
      oldWidget.paneController?._detach(this);
      widget.paneController?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.paneController?._detach(this);
    _viewport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final now = widget.controller.clock();
        final filtered = FilterEvaluator(
          graph: widget.controller.graph,
          now: now,
        ).apply(widget.filter);
        final scopedNodes = _includeScopedNodes(filtered);
        final expandableIds = _nodeIdsWithChildren(scopedNodes);
        final collapsedIds =
            widget.controller.graph.settings?.collapsedNodeIds.toSet() ??
            const <String>{};
        final visibleNodes = _applyCollapsedNodes(
          scopedNodes,
          collapsedIds: collapsedIds,
        );
        final layout = _HybridLayout.build(
          nodes: visibleNodes,
          edges: widget.controller.graph.edges,
          relationships: widget.controller.graph.relationships,
          now: now,
          urgentWindow: Duration(
            days:
                widget.controller.graph.settings?.effectiveUrgentWindowDays ??
                kDefaultUrgentWindow.inDays,
          ),
          centerParents: widget.centerParents,
          flow: _flow,
        );
        _lastLayout = layout;
        if (layout.columns.isEmpty) {
          _publishLevelInfo(HybridGraphLevelInfo.empty);
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No tasks match this filter.'),
            ),
          );
        }
        _focusedLevel = _focusedLevel.clamp(0, layout.columns.length - 1);
        _publishLevelInfo(
          HybridGraphLevelInfo(
            focusedLevel: _focusedLevel,
            levelCount: layout.columns.length,
            focusedLevelLabel: layout.levelLabel(_focusedLevel),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            _lastViewportSize = viewportSize;
            _lastSceneInsets = _sceneInsetsFor(viewportSize);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_viewport.value == Matrix4.identity()) {
                _focusLevel(_focusedLevel, preserveZoom: false);
              }
            });
            return InteractiveViewer(
              transformationController: _viewport,
              constrained: false,
              minScale: kHybridMinScale,
              maxScale: kHybridMaxScale,
              boundaryMargin: EdgeInsets.zero,
              child: _HybridCanvas(
                controller: widget.controller,
                layout: layout,
                sceneInsets: _lastSceneInsets,
                expandableIds: expandableIds,
                collapsedIds: collapsedIds,
                now: now,
                onToggleCollapsed: _toggleCollapsed,
                onSetCompleted: _setCompletedWithUndo,
                onOpenDetail: (node) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NodeDetailView(
                      controller: widget.controller,
                      nodeId: node.id,
                    ),
                  ),
                ),
                onQuickAddChild: _startQuickAddChild,
              ),
            );
          },
        );
      },
    );
  }

  /// Reports level info to the shell, deduplicating and deferring to a
  /// post-frame callback so we never call back into the parent during its own
  /// build.
  void _publishLevelInfo(HybridGraphLevelInfo info) {
    if (info == _lastReported) return;
    _lastReported = info;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLevelInfoChanged(info);
    });
  }

  void _stepLevel(int delta) => _focusLevel(_focusedLevel + delta);

  void _fitCurrentLevel() => _focusLevel(_focusedLevel, preserveZoom: false);

  void _scheduleFocus(int? level, {required bool preserveZoom}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusLevel(level ?? _focusedLevel, preserveZoom: preserveZoom);
    });
  }

  void _focusLevel(int requested, {bool preserveZoom = true}) {
    final layout = _lastLayout;
    if (layout == null || layout.columns.isEmpty) return;
    final next = requested.clamp(0, layout.columns.length - 1);
    final viewport = _lastViewportSize;
    if (viewport.width <= 0 || viewport.height <= 0) return;

    final column = layout.columns[next];
    final columnHeight = math.max(kHybridNodeHeight, column.height);
    final currentScale = _viewport.value.getMaxScaleOnAxis();
    final fitScale = math.min(
      (viewport.width - 48) / kHybridColumnWidth,
      (viewport.height - 64) / columnHeight,
    );
    final readableFitScale = math.max(kHybridReadableFocusScale, fitScale);
    final scale = (preserveZoom ? currentScale : readableFitScale).clamp(
      kHybridMinScale,
      kHybridMaxScale,
    );
    final x = _lastSceneInsets.left + layout.columnX(next);
    final y = _lastSceneInsets.top + kHybridCanvasPadding + column.minY;
    final tx = (viewport.width - kHybridColumnWidth * scale) / 2 - x * scale;
    final ty = (viewport.height - columnHeight * scale) / 2 - y * scale;
    setState(() => _focusedLevel = next);
    _viewport.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _changeZoom(double factor) {
    final current = _viewport.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(kHybridMinScale, kHybridMaxScale);
    final viewport = _lastViewportSize;
    final focal = Offset(viewport.width / 2, viewport.height / 2);
    final sceneFocal = _viewport.toScene(focal);
    final tx = focal.dx - sceneFocal.dx * next;
    final ty = focal.dy - sceneFocal.dy * next;
    _viewport.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(next, next, 1, 1);
  }

  EdgeInsets _sceneInsetsFor(Size viewport) {
    if (viewport.width <= 0 || viewport.height <= 0) {
      return EdgeInsets.zero;
    }
    return EdgeInsets.symmetric(
      horizontal: math.max(0, viewport.width - kHybridColumnWidth),
      vertical: math.max(0, viewport.height - kHybridNodeHeight),
    );
  }

  List<Node> _includeScopedNodes(List<Node> filtered) {
    if (widget.filter.ancestorGoalIds.isEmpty) return filtered;
    final visibleIds = filtered.map((n) => n.id).toSet();
    final scopedIds = widget.filter.ancestorGoalIds.toSet();
    if (scopedIds.every(visibleIds.contains)) return filtered;
    return [
      for (final node in widget.controller.graph.nodes)
        if (visibleIds.contains(node.id) || scopedIds.contains(node.id)) node,
    ];
  }

  List<Node> _applyCollapsedNodes(
    List<Node> nodes, {
    required Set<String> collapsedIds,
  }) {
    if (nodes.isEmpty || collapsedIds.isEmpty) return nodes;
    final nodeIds = nodes.map((n) => n.id).toSet();
    final hiddenIds = <String>{};
    final traversal = GraphTraversal(widget.controller.graph);
    for (final id in collapsedIds) {
      if (!nodeIds.contains(id)) continue;
      hiddenIds.addAll(traversal.descendantsOf(id).where(nodeIds.contains));
    }
    if (hiddenIds.isEmpty) return nodes;
    return [
      for (final node in nodes)
        if (!hiddenIds.contains(node.id)) node,
    ];
  }

  Set<String> _nodeIdsWithChildren(List<Node> nodes) {
    final nodeIds = nodes.map((n) => n.id).toSet();
    final out = <String>{};
    for (final edge in widget.controller.graph.edges) {
      if (!nodeIds.contains(edge.parentId)) continue;
      if (!nodeIds.contains(edge.childId)) continue;
      out.add(edge.parentId);
    }
    return out;
  }

  void _toggleCollapsed(String nodeId) {
    final current =
        widget.controller.graph.settings?.collapsedNodeIds.toSet() ??
        <String>{};
    if (!current.add(nodeId)) {
      current.remove(nodeId);
    }
    widget.controller.setCollapsedNodeIds(current.toList()..sort());
    _scheduleFocus(null, preserveZoom: true);
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

enum _HierarchyFlow { leavesToRoot, rootToLeaves }

_HierarchyFlow _flowFromSettings(ExplorerGraphFlow flow) =>
    flow == ExplorerGraphFlow.rootToLeaves
    ? _HierarchyFlow.rootToLeaves
    : _HierarchyFlow.leavesToRoot;

class _HybridCanvas extends StatelessWidget {
  const _HybridCanvas({
    required this.controller,
    required this.layout,
    required this.sceneInsets,
    required this.expandableIds,
    required this.collapsedIds,
    required this.now,
    required this.onToggleCollapsed,
    required this.onSetCompleted,
    required this.onOpenDetail,
    required this.onQuickAddChild,
  });

  final GraphController controller;
  final _HybridLayout layout;
  final EdgeInsets sceneInsets;
  final Set<String> expandableIds;
  final Set<String> collapsedIds;
  final DateTime now;
  final ValueChanged<String> onToggleCollapsed;
  final void Function(Node node, {required bool isCompleted}) onSetCompleted;
  final ValueChanged<Node> onOpenDetail;
  final ValueChanged<Node> onQuickAddChild;

  @override
  Widget build(BuildContext context) {
    final queries = NodeQueries(controller.graph);
    return SizedBox(
      width: layout.width + sceneInsets.horizontal,
      height: layout.height + sceneInsets.vertical,
      child: Stack(
        children: [
          Positioned(
            left: sceneInsets.left,
            top: sceneInsets.top,
            width: layout.width,
            height: layout.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HybridEdgePainter(
                      layout: layout,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                for (var level = 0; level < layout.columns.length; level++)
                  _LevelLabel(
                    x: layout.columnX(level),
                    label: layout.levelLabel(level),
                  ),
                for (final item in layout.items)
                  Positioned(
                    left: item.x,
                    top: item.y,
                    width: kHybridColumnWidth,
                    height: kHybridNodeHeight,
                    child: _HybridNodeCard(
                      node: item.node,
                      now: now,
                      queries: queries,
                      edgeContribution: item.primaryContribution,
                      hasChildren: expandableIds.contains(item.node.id),
                      isCollapsed: collapsedIds.contains(item.node.id),
                      onToggleCollapsed: () => onToggleCollapsed(item.node.id),
                      onSetCompleted: (isCompleted) =>
                          onSetCompleted(item.node, isCompleted: isCompleted),
                      onOpenDetail: () => onOpenDetail(item.node),
                      onQuickAddChild: () => onQuickAddChild(item.node),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelLabel extends StatelessWidget {
  const _LevelLabel({required this.x, required this.label});

  final double x;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: 12,
      width: kHybridColumnWidth,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HybridNodeCard extends StatelessWidget {
  const _HybridNodeCard({
    required this.node,
    required this.now,
    required this.queries,
    required this.edgeContribution,
    required this.hasChildren,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.onSetCompleted,
    required this.onOpenDetail,
    required this.onQuickAddChild,
  });

  final Node node;
  final DateTime now;
  final NodeQueries queries;
  final Contribution? edgeContribution;
  final bool hasChildren;
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<bool> onSetCompleted;
  final VoidCallback onOpenDetail;
  final VoidCallback onQuickAddChild;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = switch (edgeContribution) {
      Contribution.mandatory => scheme.primary,
      Contribution.helpful => scheme.outlineVariant,
      null => Colors.transparent,
    };
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: borderColor,
                width: edgeContribution == null ? 0 : kContributionBorderWidth,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(
            children: [
              _leadingFor(context),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: _isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (_subtitleFor() case final subtitle?) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasChildren)
                IconButton(
                  tooltip: isCollapsed
                      ? 'Show child tasks'
                      : 'Hide child tasks',
                  icon: Icon(
                    isCollapsed ? Icons.unfold_more : Icons.unfold_less,
                  ),
                  iconSize: 20,
                  onPressed: onToggleCollapsed,
                ),
              IconButton(
                tooltip: 'Add child',
                icon: const Icon(Icons.add),
                iconSize: 20,
                onPressed: onQuickAddChild,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isCompleted {
    final c = node.status.completion;
    if (c == null) return false;
    return !node.status.isOngoingAt(now);
  }

  Widget _leadingFor(BuildContext context) {
    if (node.status.completion == null) {
      return Icon(
        Icons.flag_outlined,
        size: 22,
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
          size: 22,
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
          size: 22,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    return Checkbox(
      value: _isCompleted,
      onChanged: (value) {
        if (value != null) onSetCompleted(value);
      },
    );
  }

  String? _subtitleFor() {
    final parts = <String>[];
    final inheritedDeadline = queries.inheritedDeadline(node.id);
    if (node.deadline != null) {
      parts.add('Due ${formatDate(node.deadline!)}');
    } else if (inheritedDeadline != null) {
      parts.add('Due ${formatDate(inheritedDeadline)}');
    }
    final c = node.status.completion;
    if (c is NTimesCompletion) {
      parts.add('${c.remainingCount} of ${c.targetCount} left');
    } else if (c is PeriodicCompletion) {
      parts.add('Every ${c.intervalDaysSinceLastCompletion}d');
    }
    if (node.impact != null && node.impact != Impact.minimal) {
      parts.add(impactLabel(node.impact!));
    }
    return parts.isEmpty ? null : parts.join(' • ');
  }
}

class _HybridEdgePainter extends CustomPainter {
  const _HybridEdgePainter({required this.layout, required this.color});

  final _HybridLayout layout;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in layout.visibleEdges) {
      final child = layout.itemById[edge.childId];
      final parent = layout.itemById[edge.parentId];
      if (child == null || parent == null) continue;
      final (from, to) = layout.flow == _HierarchyFlow.leavesToRoot
          ? (child, parent)
          : (parent, child);
      final start = Offset(from.x + kHybridColumnWidth, from.y + 39);
      final end = Offset(to.x, to.y + 39);
      final dx = end.dx - start.dx;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + dx * 0.42,
          start.dy,
          end.dx - dx * 0.42,
          end.dy,
          end.dx,
          end.dy,
        );
      final edgePaint = Paint()
        ..color = color.withValues(
          alpha: edge.contribution == Contribution.mandatory ? 0.58 : 0.30,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = edge.contribution == Contribution.mandatory ? 2 : 1.3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HybridEdgePainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.color != color;
}

class _HybridLayout {
  const _HybridLayout({
    required this.columns,
    required this.items,
    required this.itemById,
    required this.visibleEdges,
    required this.flow,
    required this.width,
    required this.height,
  });

  final List<_HybridColumn> columns;
  final List<_HybridItem> items;
  final Map<String, _HybridItem> itemById;
  final List<_LayoutEdge> visibleEdges;
  final _HierarchyFlow flow;
  final double width;
  final double height;

  double columnX(int level) =>
      kHybridCanvasPadding + level * (kHybridColumnWidth + kHybridColumnGap);

  static _HybridLayout build({
    required List<Node> nodes,
    required List<Edge> edges,
    required List<NodeRelationship> relationships,
    required DateTime now,
    required Duration urgentWindow,
    required bool centerParents,
    required _HierarchyFlow flow,
  }) {
    if (nodes.isEmpty) return _HybridLayout.empty();
    final nodeById = {for (final n in nodes) n.id: n};
    final nodeIds = nodeById.keys.toSet();
    final childrenByParent = <String, List<String>>{};
    final parentsByChild = <String, List<String>>{};
    final layoutEdges = <_LayoutEdge>[];
    for (final edge in edges) {
      if (!nodeIds.contains(edge.childId) || !nodeIds.contains(edge.parentId)) {
        continue;
      }
      (childrenByParent[edge.parentId] ??= <String>[]).add(edge.childId);
      (parentsByChild[edge.childId] ??= <String>[]).add(edge.parentId);
      layoutEdges.add(
        _LayoutEdge(
          childId: edge.childId,
          parentId: edge.parentId,
          contribution: edge.contribution,
        ),
      );
    }

    final levels = flow == _HierarchyFlow.leavesToRoot
        ? _levelsFromLeaves(nodeIds, childrenByParent)
        : _levelsFromRoots(nodeIds, parentsByChild);
    final effective = _effectiveScores(nodeById, childrenByParent);
    final ordering = NodeOrdering(urgentWindow: urgentWindow);
    final columns = <_HybridColumn>[];
    final itemById = <String, _HybridItem>{};
    final items = <_HybridItem>[];

    List<String> previousOrder = const [];
    for (var level = 0; level < levels.length; level++) {
      final ids = levels[level];
      var ordered = flow == _HierarchyFlow.leavesToRoot
          ? _orderLevelFromLeaves(
              ids: ids,
              nodeById: nodeById,
              childrenByParent: childrenByParent,
              parentsByChild: parentsByChild,
              previousOrder: previousOrder,
              effective: effective,
              relationships: relationships,
              now: now,
              ordering: ordering,
            )
          : _orderLevelFromRoots(
              ids: ids,
              nodeById: nodeById,
              parentsByChild: parentsByChild,
              previousOrder: previousOrder,
              effective: effective,
              relationships: relationships,
              now: now,
              ordering: ordering,
            );
      final relatedPreviousById = flow == _HierarchyFlow.leavesToRoot
          ? childrenByParent
          : parentsByChild;
      final yById = centerParents && level > 0
          ? _centeredY(
              ordered,
              relatedPreviousById: relatedPreviousById,
              previousItemById: itemById,
            )
          : _packedY(ordered);
      final x =
          kHybridCanvasPadding +
          level * (kHybridColumnWidth + kHybridColumnGap);
      final columnItems = <_HybridItem>[];
      for (final id in ordered) {
        final item = _HybridItem(
          node: nodeById[id]!,
          level: level,
          x: x,
          y: kHybridCanvasPadding + yById[id]!,
          primaryContribution: _primaryContribution(
            id,
            layoutEdges,
            flow: flow,
            level: level,
          ),
        );
        itemById[id] = item;
        items.add(item);
        columnItems.add(item);
      }
      columns.add(_HybridColumn(items: columnItems));
      previousOrder = ordered;
    }

    final maxHeight = columns.fold<double>(
      0,
      (max, column) => math.max(max, column.height),
    );
    final width =
        kHybridCanvasPadding * 2 +
        columns.length * kHybridColumnWidth +
        math.max(0, columns.length - 1) * kHybridColumnGap;
    final height = kHybridCanvasPadding * 2 + 32 + maxHeight;
    return _HybridLayout(
      columns: columns,
      items: items,
      itemById: itemById,
      visibleEdges: layoutEdges,
      flow: flow,
      width: width,
      height: math.max(360, height),
    );
  }

  static _HybridLayout empty() => const _HybridLayout(
    columns: [],
    items: [],
    itemById: {},
    visibleEdges: [],
    flow: _HierarchyFlow.leavesToRoot,
    width: 0,
    height: 0,
  );

  String levelLabel(int level) {
    if (columns.isEmpty) return '';
    final last = columns.length - 1;
    if (flow == _HierarchyFlow.leavesToRoot) {
      if (level == 0) return 'Leaves';
      if (level == last) return 'Root Goal';
      return 'Level $level';
    }
    if (level == 0) return 'Root Goal';
    if (level == last) return 'Leaves';
    return 'Level $level';
  }
}

class _HybridColumn {
  const _HybridColumn({required this.items});

  final List<_HybridItem> items;

  double get minY {
    if (items.isEmpty) return 0;
    return items.map((i) => i.y).reduce(math.min) - kHybridCanvasPadding;
  }

  double get height {
    if (items.isEmpty) return kHybridNodeHeight;
    final minTop = items.map((i) => i.y).reduce(math.min);
    final maxBottom = items
        .map((i) => i.y + kHybridNodeHeight)
        .reduce(math.max);
    return maxBottom - minTop;
  }
}

class _HybridItem {
  const _HybridItem({
    required this.node,
    required this.level,
    required this.x,
    required this.y,
    required this.primaryContribution,
  });

  final Node node;
  final int level;
  final double x;
  final double y;
  final Contribution? primaryContribution;
}

class _LayoutEdge {
  const _LayoutEdge({
    required this.childId,
    required this.parentId,
    required this.contribution,
  });

  final String childId;
  final String parentId;
  final Contribution contribution;
}

List<List<String>> _levelsFromLeaves(
  Set<String> nodeIds,
  Map<String, List<String>> childrenByParent,
) {
  final memo = <String, int>{};
  int levelOf(String id, Set<String> visiting) {
    final cached = memo[id];
    if (cached != null) return cached;
    if (!visiting.add(id)) return 0;
    final children = childrenByParent[id] ?? const <String>[];
    final visibleChildren = children.where(nodeIds.contains).toList();
    if (visibleChildren.isEmpty) {
      memo[id] = 0;
      return 0;
    }
    final level =
        1 +
        visibleChildren
            .map((childId) => levelOf(childId, {...visiting}))
            .reduce(math.max);
    memo[id] = level;
    return level;
  }

  var maxLevel = 0;
  for (final id in nodeIds) {
    maxLevel = math.max(maxLevel, levelOf(id, <String>{}));
  }
  final levels = List.generate(maxLevel + 1, (_) => <String>[]);
  for (final id in nodeIds) {
    levels[memo[id] ?? 0].add(id);
  }
  return levels.where((level) => level.isNotEmpty).toList(growable: false);
}

List<List<String>> _levelsFromRoots(
  Set<String> nodeIds,
  Map<String, List<String>> parentsByChild,
) {
  final memo = <String, int>{};
  int levelOf(String id, Set<String> visiting) {
    final cached = memo[id];
    if (cached != null) return cached;
    if (!visiting.add(id)) return 0;
    final parents = parentsByChild[id] ?? const <String>[];
    final visibleParents = parents.where(nodeIds.contains).toList();
    if (visibleParents.isEmpty) {
      memo[id] = 0;
      return 0;
    }
    final level =
        1 +
        visibleParents
            .map((parentId) => levelOf(parentId, {...visiting}))
            .reduce(math.max);
    memo[id] = level;
    return level;
  }

  var maxLevel = 0;
  for (final id in nodeIds) {
    maxLevel = math.max(maxLevel, levelOf(id, <String>{}));
  }
  final levels = List.generate(maxLevel + 1, (_) => <String>[]);
  for (final id in nodeIds) {
    levels[memo[id] ?? 0].add(id);
  }
  return levels.where((level) => level.isNotEmpty).toList(growable: false);
}

Map<String, _EffectiveScore> _effectiveScores(
  Map<String, Node> nodeById,
  Map<String, List<String>> childrenByParent,
) {
  final cache = <String, _EffectiveScore>{};
  _EffectiveScore compute(String id, Set<String> visiting) {
    final cached = cache[id];
    if (cached != null) return cached;
    if (!visiting.add(id)) {
      return const _EffectiveScore(deadline: null, impact: null);
    }
    final node = nodeById[id]!;
    var deadline = node.deadline;
    var impact = node.impact;
    for (final childId in childrenByParent[id] ?? const <String>[]) {
      if (!nodeById.containsKey(childId)) continue;
      final child = compute(childId, {...visiting});
      deadline ??= child.deadline;
      if (deadline != null &&
          child.deadline != null &&
          child.deadline!.isBefore(deadline)) {
        deadline = child.deadline;
      }
      if (impact == null || (child.impact?.weight ?? -1) > (impact.weight)) {
        impact = child.impact ?? impact;
      }
    }
    final score = _EffectiveScore(deadline: deadline, impact: impact);
    cache[id] = score;
    return score;
  }

  for (final id in nodeById.keys) {
    compute(id, <String>{});
  }
  return cache;
}

List<String> _orderLevelFromLeaves({
  required List<String> ids,
  required Map<String, Node> nodeById,
  required Map<String, List<String>> childrenByParent,
  required Map<String, List<String>> parentsByChild,
  required List<String> previousOrder,
  required Map<String, _EffectiveScore> effective,
  required List<NodeRelationship> relationships,
  required DateTime now,
  required NodeOrdering ordering,
}) {
  if (ids.length <= 1) return ids;
  final previousPosition = {
    for (var i = 0; i < previousOrder.length; i++) previousOrder[i]: i,
  };
  final parentSorted = <String, double>{};
  for (final id in ids) {
    final childPositions = [
      for (final childId in childrenByParent[id] ?? const <String>[])
        if (previousPosition.containsKey(childId))
          previousPosition[childId]!.toDouble(),
    ];
    if (childPositions.isNotEmpty) {
      parentSorted[id] =
          childPositions.reduce((a, b) => a + b) / childPositions.length;
    }
  }

  if (previousOrder.isEmpty) {
    final groups = <String, List<String>>{};
    final noParent = <String>[];
    for (final id in ids) {
      final parentIds = parentsByChild[id] ?? const <String>[];
      if (parentIds.isEmpty) {
        noParent.add(id);
      } else {
        final key = parentIds.first;
        (groups[key] ??= <String>[]).add(id);
      }
    }
    final parentOrder = ordering
        .defaultOrder(
          [
            for (final parentId in groups.keys)
              if (nodeById.containsKey(parentId))
                _virtualWithEffective(nodeById[parentId]!, effective[parentId]),
          ],
          now: now,
          relationships: relationships,
        )
        .map((n) => n.id)
        .toList();
    final out = <String>[];
    for (final parentId in parentOrder) {
      out.addAll(
        _scoreOrder(
          groups[parentId]!,
          nodeById,
          effective,
          ordering,
          now,
          relationships,
        ),
      );
    }
    out.addAll(
      _scoreOrder(noParent, nodeById, effective, ordering, now, relationships),
    );
    return out;
  }

  final scoreOrdered = _scoreOrder(
    ids,
    nodeById,
    effective,
    ordering,
    now,
    relationships,
  );
  final scorePosition = {
    for (var i = 0; i < scoreOrdered.length; i++) scoreOrdered[i]: i,
  };
  return [...ids]..sort((a, b) {
    final aGroup = parentSorted[a] ?? double.infinity;
    final bGroup = parentSorted[b] ?? double.infinity;
    final groupCmp = aGroup.compareTo(bGroup);
    if (groupCmp != 0) return groupCmp;
    return scorePosition[a]!.compareTo(scorePosition[b]!);
  });
}

List<String> _orderLevelFromRoots({
  required List<String> ids,
  required Map<String, Node> nodeById,
  required Map<String, List<String>> parentsByChild,
  required List<String> previousOrder,
  required Map<String, _EffectiveScore> effective,
  required List<NodeRelationship> relationships,
  required DateTime now,
  required NodeOrdering ordering,
}) {
  if (ids.length <= 1) return ids;
  if (previousOrder.isEmpty) {
    return _scoreOrder(ids, nodeById, effective, ordering, now, relationships);
  }

  final previousPosition = {
    for (var i = 0; i < previousOrder.length; i++) previousOrder[i]: i,
  };
  final scoreOrdered = _scoreOrder(
    ids,
    nodeById,
    effective,
    ordering,
    now,
    relationships,
  );
  final scorePosition = {
    for (var i = 0; i < scoreOrdered.length; i++) scoreOrdered[i]: i,
  };
  return [...ids]..sort((a, b) {
    final aGroup = _averagePreviousPosition(
      parentsByChild[a] ?? const <String>[],
      previousPosition,
    );
    final bGroup = _averagePreviousPosition(
      parentsByChild[b] ?? const <String>[],
      previousPosition,
    );
    final groupCmp = aGroup.compareTo(bGroup);
    if (groupCmp != 0) return groupCmp;
    return scorePosition[a]!.compareTo(scorePosition[b]!);
  });
}

double _averagePreviousPosition(
  List<String> relatedIds,
  Map<String, int> previousPosition,
) {
  final positions = [
    for (final id in relatedIds)
      if (previousPosition.containsKey(id)) previousPosition[id]!.toDouble(),
  ];
  if (positions.isEmpty) return double.infinity;
  return positions.reduce((a, b) => a + b) / positions.length;
}

List<String> _scoreOrder(
  List<String> ids,
  Map<String, Node> nodeById,
  Map<String, _EffectiveScore> effective,
  NodeOrdering ordering,
  DateTime now,
  List<NodeRelationship> relationships,
) {
  final ordered = ordering.defaultOrder(
    [for (final id in ids) _virtualWithEffective(nodeById[id]!, effective[id])],
    now: now,
    relationships: relationships,
  );
  return ordered.map((n) => n.id).toList(growable: false);
}

Node _virtualWithEffective(Node real, _EffectiveScore? effective) {
  return Node(
    id: real.id,
    title: real.title,
    status: real.status,
    createdAt: real.createdAt,
    deadline: effective?.deadline,
    impact: effective?.impact,
  );
}

Map<String, double> _packedY(List<String> ordered) => {
  for (var i = 0; i < ordered.length; i++)
    ordered[i]: 32 + i * (kHybridNodeHeight + kHybridNodeGap),
};

Map<String, double> _centeredY(
  List<String> ordered, {
  required Map<String, List<String>> relatedPreviousById,
  required Map<String, _HybridItem> previousItemById,
}) {
  final out = <String, double>{};
  var minTop = 32.0;
  for (final id in ordered) {
    final relatedIds = relatedPreviousById[id] ?? const <String>[];
    final centers = [
      for (final relatedId in relatedIds)
        if (previousItemById[relatedId] case final previous?)
          previous.y - kHybridCanvasPadding + kHybridNodeHeight / 2,
    ];
    var y = centers.isEmpty
        ? minTop
        : centers.reduce((a, b) => a + b) / centers.length -
              kHybridNodeHeight / 2;
    if (y < minTop) y = minTop;
    out[id] = y;
    minTop = y + kHybridNodeHeight + kHybridNodeGap;
  }
  return out;
}

Contribution? _primaryContribution(
  String nodeId,
  List<_LayoutEdge> edges, {
  required _HierarchyFlow flow,
  required int level,
}) {
  final related = edges.where((e) {
    if (flow == _HierarchyFlow.leavesToRoot) {
      return level == 0 ? e.childId == nodeId : e.parentId == nodeId;
    }
    return level == 0 ? e.parentId == nodeId : e.childId == nodeId;
  });
  if (related.any((e) => e.contribution == Contribution.mandatory)) {
    return Contribution.mandatory;
  }
  if (related.any((e) => e.contribution == Contribution.helpful)) {
    return Contribution.helpful;
  }
  return null;
}

class _EffectiveScore {
  const _EffectiveScore({required this.deadline, required this.impact});
  final DateTime? deadline;
  final Impact? impact;
}
