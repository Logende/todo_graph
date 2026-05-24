import '../model/edge.dart';
import '../model/lakshya_graph.dart';
import '../model/node.dart';
import 'graph_traversal.dart';

/// Pure transformations on a [LakshyaGraph]. Every method returns a new
/// graph; the input is never mutated.
///
/// Validation rules:
/// * Node ids are unique.
/// * Edge ids are unique.
/// * Every edge references existing child and parent nodes.
/// * Edges cannot form cycles (the graph is a DAG).
class GraphMutator {
  const GraphMutator();

  LakshyaGraph addNode(LakshyaGraph graph, Node node) {
    if (graph.nodes.any((n) => n.id == node.id)) {
      throw ArgumentError.value(
        node.id,
        'node.id',
        'a node with this id already exists',
      );
    }
    return _copyWith(graph, nodes: [...graph.nodes, node]);
  }

  LakshyaGraph updateNode(LakshyaGraph graph, Node updated) {
    final index = graph.nodes.indexWhere((n) => n.id == updated.id);
    if (index < 0) {
      throw ArgumentError.value(
        updated.id,
        'node.id',
        'no node with this id exists',
      );
    }
    final next = [...graph.nodes];
    next[index] = updated;
    return _copyWith(graph, nodes: next);
  }

  LakshyaGraph deleteNode(LakshyaGraph graph, String nodeId) {
    if (!graph.nodes.any((n) => n.id == nodeId)) {
      throw ArgumentError.value(
        nodeId,
        'nodeId',
        'no node with this id exists',
      );
    }
    return _copyWith(
      graph,
      nodes: graph.nodes.where((n) => n.id != nodeId).toList(),
      edges: graph.edges
          .where((e) => e.childId != nodeId && e.parentId != nodeId)
          .toList(),
    );
  }

  LakshyaGraph addEdge(LakshyaGraph graph, Edge edge) {
    if (graph.edges.any((e) => e.id == edge.id)) {
      throw ArgumentError.value(
        edge.id,
        'edge.id',
        'an edge with this id already exists',
      );
    }
    final nodeIds = graph.nodes.map((n) => n.id).toSet();
    if (!nodeIds.contains(edge.childId)) {
      throw ArgumentError.value(
        edge.childId,
        'edge.childId',
        'no node with this id exists',
      );
    }
    if (!nodeIds.contains(edge.parentId)) {
      throw ArgumentError.value(
        edge.parentId,
        'edge.parentId',
        'no node with this id exists',
      );
    }
    final traversal = GraphTraversal(graph);
    if (traversal.wouldFormCycle(
        childId: edge.childId, parentId: edge.parentId)) {
      throw StateError(
        'edge from ${edge.childId} to ${edge.parentId} would form a cycle',
      );
    }
    return _copyWith(graph, edges: [...graph.edges, edge]);
  }

  LakshyaGraph removeEdge(LakshyaGraph graph, String edgeId) {
    if (!graph.edges.any((e) => e.id == edgeId)) {
      throw ArgumentError.value(
        edgeId,
        'edgeId',
        'no edge with this id exists',
      );
    }
    return _copyWith(
      graph,
      edges: graph.edges.where((e) => e.id != edgeId).toList(),
    );
  }

  LakshyaGraph _copyWith(
    LakshyaGraph graph, {
    List<Node>? nodes,
    List<Edge>? edges,
  }) {
    return LakshyaGraph(
      schemaVersion: graph.schemaVersion,
      nodes: nodes ?? graph.nodes,
      edges: edges ?? graph.edges,
      priorityPins: graph.priorityPins,
      filterPresets: graph.filterPresets,
      settings: graph.settings,
    );
  }
}
