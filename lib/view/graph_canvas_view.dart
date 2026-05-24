import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart' as gv;

import '../app/graph_controller.dart';
import '../model/node.dart' as model;
import 'node_detail_view.dart';

/// Pan/zoom-able layered rendering of the full goal graph. Each tap on a
/// node opens [NodeDetailView] for inspection.
///
/// Uses graphview's Sugiyama layout, which produces a clean top-down DAG
/// view that matches the user's mental model of "high-level goals at the
/// top, leaf tasks at the bottom".
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
      ..nodeSeparation = 24
      ..levelSeparation = 56
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
    return InteractiveViewer(
      transformationController: _viewport,
      constrained: false,
      minScale: 0.3,
      maxScale: 4,
      boundaryMargin: const EdgeInsets.all(400),
      child: gv.GraphView(
        graph: _graph,
        algorithm: gv.SugiyamaAlgorithm(_config),
        builder: (layoutNode) {
          final id = layoutNode.key!.value as String;
          final modelNode = modelNodeById[id];
          if (modelNode == null) return const SizedBox.shrink();
          return _NodeBox(
            node: modelNode,
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
    );
  }
}

class _NodeBox extends StatelessWidget {
  const _NodeBox({required this.node, required this.onTap});

  final model.Node node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBackground = node.status.completion == null;
    return Material(
      color: isBackground
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 120,
            maxWidth: 200,
            minHeight: 36,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              node.title,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
