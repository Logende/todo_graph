import '../model/edge.dart';
import '../model/lakshya_graph.dart';
import '../model/node.dart';
import '../model/node_relationship.dart';
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
    _requireUniqueId(graph.nodes.map((n) => n.id), node.id, label: 'node.id');
    return graph.copyWith(nodes: [...graph.nodes, node]);
  }

  LakshyaGraph updateNode(LakshyaGraph graph, Node updated) {
    final index = graph.nodes.indexWhere((n) => n.id == updated.id);
    _requirePresent(index, updated.id, label: 'node.id');
    final next = [...graph.nodes];
    next[index] = updated;
    return graph.copyWith(nodes: next);
  }

  LakshyaGraph deleteNode(LakshyaGraph graph, String nodeId) {
    final index = graph.nodes.indexWhere((n) => n.id == nodeId);
    _requirePresent(index, nodeId, label: 'nodeId');
    return graph.copyWith(
      nodes: graph.nodes.where((n) => n.id != nodeId).toList(),
      edges: graph.edges
          .where((e) => e.childId != nodeId && e.parentId != nodeId)
          .toList(),
      relationships: graph.relationships
          .where((r) => r.fromNodeId != nodeId && r.toNodeId != nodeId)
          .toList(),
    );
  }

  LakshyaGraph addEdge(LakshyaGraph graph, Edge edge) {
    _requireUniqueId(graph.edges.map((e) => e.id), edge.id, label: 'edge.id');
    final nodeIds = graph.nodes.map((n) => n.id).toSet();
    _requireKnownNode(nodeIds, edge.childId, label: 'edge.childId');
    _requireKnownNode(nodeIds, edge.parentId, label: 'edge.parentId');
    if (GraphTraversal(graph).wouldFormCycle(
        childId: edge.childId, parentId: edge.parentId)) {
      throw StateError(
        'edge from ${edge.childId} to ${edge.parentId} would form a cycle',
      );
    }
    return graph.copyWith(edges: [...graph.edges, edge]);
  }

  LakshyaGraph removeEdge(LakshyaGraph graph, String edgeId) {
    final index = graph.edges.indexWhere((e) => e.id == edgeId);
    _requirePresent(index, edgeId, label: 'edgeId');
    return graph.copyWith(
      edges: graph.edges.where((e) => e.id != edgeId).toList(),
    );
  }

  LakshyaGraph addRelationship(
    LakshyaGraph graph,
    NodeRelationship relationship,
  ) {
    _requireUniqueId(
      graph.relationships.map((r) => r.id),
      relationship.id,
      label: 'relationship.id',
    );
    final nodeIds = graph.nodes.map((n) => n.id).toSet();
    _requireKnownNode(
      nodeIds,
      relationship.fromNodeId,
      label: 'relationship.fromNodeId',
    );
    _requireKnownNode(
      nodeIds,
      relationship.toNodeId,
      label: 'relationship.toNodeId',
    );
    if (relationship.fromNodeId == relationship.toNodeId) {
      throw ArgumentError.value(
        relationship.fromNodeId,
        'relationship',
        'a relationship cannot connect a node to itself',
      );
    }
    return graph.copyWith(
      relationships: [...graph.relationships, relationship],
    );
  }

  LakshyaGraph removeRelationship(LakshyaGraph graph, String relationshipId) {
    final index =
        graph.relationships.indexWhere((r) => r.id == relationshipId);
    _requirePresent(index, relationshipId, label: 'relationshipId');
    return graph.copyWith(
      relationships:
          graph.relationships.where((r) => r.id != relationshipId).toList(),
    );
  }

  void _requireUniqueId(
    Iterable<String> existingIds,
    String candidate, {
    required String label,
  }) {
    if (existingIds.contains(candidate)) {
      throw ArgumentError.value(
        candidate,
        label,
        'an item with this id already exists',
      );
    }
  }

  void _requirePresent(int index, String id, {required String label}) {
    if (index < 0) {
      throw ArgumentError.value(id, label, 'no item with this id exists');
    }
  }

  void _requireKnownNode(
    Set<String> knownNodeIds,
    String candidate, {
    required String label,
  }) {
    if (!knownNodeIds.contains(candidate)) {
      throw ArgumentError.value(
        candidate,
        label,
        'no node with this id exists',
      );
    }
  }
}
