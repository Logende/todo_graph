import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart' as gv;

import '../app/graph_controller.dart';
import '../model/completion.dart';
import '../model/impact.dart';
import '../model/node.dart' as model;
import '../model/node_status.dart';
import '../model/settings.dart';
import 'node_detail_view.dart';

import 'view_helpers.dart';
/// Pan/zoom-able layered rendering of the full goal graph. Each tap on a
/// node opens [NodeDetailView] for inspection.
///
/// Uses graphview's Sugiyama layout, which produces a clean top-down DAG
/// view that matches the user's mental model of "high-level goals at the
/// top, leaf tasks at the bottom". Nodes are styled by status (background
/// goal vs. ongoing vs. completed) and accented when their deadline is
/// inside the configured urgent window.
class GraphCanvasView extends StatelessWidget {
  const GraphCanvasView({super.key, required this.controller});

  final GraphController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Graph')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.graph.nodes.isEmpty) {
            return const Center(
              child: Text('No nodes to draw yet — add a task to start.'),
            );
          }
          return _GraphCanvas(
            controller: controller,
            modelNodes: controller.graph.nodes,
          );
        },
      ),
    );
  }
}

class _GraphCanvas extends StatefulWidget {
  const _GraphCanvas({required this.controller, required this.modelNodes});

  final GraphController controller;
  final List<model.Node> modelNodes;

  @override
  State<_GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<_GraphCanvas> {
  late final TransformationController _viewport = TransformationController();
  late gv.Graph _graph;
  late gv.SugiyamaConfiguration _config;

  @override
  void initState() {
    super.initState();
    _config = gv.SugiyamaConfiguration()
      ..nodeSeparation = 32
      ..levelSeparation = 72
      ..orientation = gv.SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;
    _graph = _buildLayoutGraph();
  }

  @override
  void didUpdateWidget(covariant _GraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _graph = _buildLayoutGraph();
  }

  @override
  void dispose() {
    _viewport.dispose();
    super.dispose();
  }

  gv.Graph _buildLayoutGraph() {
    final graph = gv.Graph()..isTree = false;
    final layoutNodeById = <String, gv.Node>{};
    for (final modelNode in widget.modelNodes) {
      final layoutNode = gv.Node.Id(modelNode.id);
      layoutNodeById[modelNode.id] = layoutNode;
      graph.addNode(layoutNode);
    }
    for (final edge in widget.controller.graph.edges) {
      final from = layoutNodeById[edge.childId];
      final to = layoutNodeById[edge.parentId];
      if (from == null || to == null) continue;
      // Parent is the higher level — draw edge upward so Sugiyama lays out
      // the root at the top.
      graph.addEdge(to, from);
    }
    return graph;
  }

  @override
  Widget build(BuildContext context) {
    final modelNodeById = {for (final n in widget.modelNodes) n.id: n};
    final scheme = Theme.of(context).colorScheme;
    final now = widget.controller.clock();
    final urgentWindow = Duration(
      days: widget.controller.graph.settings?.effectiveUrgentWindowDays ??
          kDefaultUrgentWindowDays,
    );
    final edgePaint = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    return Container(
      color: scheme.surface,
      child: InteractiveViewer(
        transformationController: _viewport,
        constrained: false,
        minScale: 0.3,
        maxScale: 4,
        boundaryMargin: const EdgeInsets.all(400),
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: gv.GraphView(
            graph: _graph,
            algorithm: gv.SugiyamaAlgorithm(_config),
            paint: edgePaint,
            builder: (layoutNode) {
              final id = layoutNode.key!.value as String;
              final modelNode = modelNodeById[id];
              if (modelNode == null) return const SizedBox.shrink();
              return _NodeBox(
                node: modelNode,
                now: now,
                urgentWindow: urgentWindow,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NodeDetailView(
                      controller: widget.controller,
                      nodeId: modelNode.id,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NodeBox extends StatefulWidget {
  const _NodeBox({
    required this.node,
    required this.now,
    required this.urgentWindow,
    required this.onTap,
  });

  final model.Node node;
  final DateTime now;
  final Duration urgentWindow;
  final VoidCallback onTap;

  @override
  State<_NodeBox> createState() => _NodeBoxState();
}

class _NodeBoxState extends State<_NodeBox> {
  bool _hovered = false;

  bool get _isBackground => widget.node.status.completion == null;
  bool get _isCompleted {
    final c = widget.node.status.completion;
    if (c == null) return false;
    return !widget.node.status.isOngoingAt(widget.now);
  }

  bool get _isUrgent {
    final d = widget.node.deadline;
    if (d == null) return false;
    final cutoff = widget.now.add(widget.urgentWindow);
    return !d.isAfter(cutoff) && !d.isBefore(widget.now);
  }

  bool get _isOverdue {
    final d = widget.node.deadline;
    if (d == null) return false;
    return d.isBefore(widget.now);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = _palette(scheme);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(
            minWidth: 160,
            maxWidth: 240,
            minHeight: 56,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.gradient,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.border,
              width: palette.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: _hovered ? 0.18 : 0.10,
                ),
                blurRadius: _hovered ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleRow(
                      title: widget.node.title,
                      titleColor: palette.titleColor,
                      isCompleted: _isCompleted,
                      icon: _leadingIconFor(widget.node.status),
                      iconColor: palette.iconColor,
                    ),
                    if (_subtitleFor() != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _subtitleFor()!,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: palette.subtitleColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _NodePalette _palette(ColorScheme scheme) {
    if (_isCompleted) {
      return _NodePalette(
        gradient: [
          scheme.surfaceContainerHigh,
          scheme.surfaceContainer,
        ],
        border: scheme.outlineVariant,
        borderWidth: 1,
        titleColor: scheme.onSurface.withValues(alpha: 0.55),
        subtitleColor: scheme.onSurface.withValues(alpha: 0.4),
        iconColor: scheme.outline,
      );
    }
    if (_isOverdue) {
      return _NodePalette(
        gradient: [scheme.errorContainer, scheme.errorContainer],
        border: scheme.error,
        borderWidth: 1.6,
        titleColor: scheme.onErrorContainer,
        subtitleColor: scheme.onErrorContainer.withValues(alpha: 0.75),
        iconColor: scheme.onErrorContainer,
      );
    }
    if (_isUrgent) {
      return _NodePalette(
        gradient: [scheme.tertiaryContainer, scheme.tertiaryContainer],
        border: scheme.tertiary,
        borderWidth: 1.4,
        titleColor: scheme.onTertiaryContainer,
        subtitleColor: scheme.onTertiaryContainer.withValues(alpha: 0.75),
        iconColor: scheme.onTertiaryContainer,
      );
    }
    if (_isBackground) {
      return _NodePalette(
        gradient: [
          scheme.primaryContainer,
          Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.18),
            scheme.surfaceContainerHighest,
          ),
        ],
        border: scheme.primary.withValues(alpha: 0.35),
        borderWidth: 1,
        titleColor: scheme.onPrimaryContainer,
        subtitleColor: scheme.onPrimaryContainer.withValues(alpha: 0.75),
        iconColor: scheme.primary,
      );
    }
    return _NodePalette(
      gradient: [
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ],
      border: scheme.outlineVariant,
      borderWidth: 1,
      titleColor: scheme.onSurface,
      subtitleColor: scheme.onSurfaceVariant,
      iconColor: scheme.primary,
    );
  }

  IconData _leadingIconFor(NodeStatus status) {
    if (status.completion == null) return Icons.flag_outlined;
    return switch (status.completion) {
      OneTimeCompletion() => Icons.check_circle_outline,
      NTimesCompletion() => Icons.repeat,
      PeriodicCompletion() => Icons.refresh,
      null => Icons.flag_outlined,
    };
  }

  String? _subtitleFor() {
    final parts = <String>[];
    final d = widget.node.deadline;
    if (d != null) {
      parts.add(_formatDeadline(d, widget.now));
    }
    final impact = widget.node.impact;
    if (impact != null && impact != Impact.minimal) {
      parts.add(impactLabel(impact));
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.titleColor,
    required this.isCompleted,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final Color titleColor;
  final bool isCompleted;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: titleColor.withValues(alpha: 0.6),
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _NodePalette {
  const _NodePalette({
    required this.gradient,
    required this.border,
    required this.borderWidth,
    required this.titleColor,
    required this.subtitleColor,
    required this.iconColor,
  });

  final List<Color> gradient;
  final Color border;
  final double borderWidth;
  final Color titleColor;
  final Color subtitleColor;
  final Color iconColor;
}


String _formatDeadline(DateTime deadline, DateTime now) {
  final days = deadline.difference(now).inDays;
  if (days < -1) return '${-days}d overdue';
  if (days < 0) return 'Overdue today';
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days < 7) return 'Due in ${days}d';
  if (days < 30) return 'Due in ${(days / 7).round()}w';
  return 'Due ${deadline.year}-'
      '${deadline.month.toString().padLeft(2, '0')}-'
      '${deadline.day.toString().padLeft(2, '0')}';
}
