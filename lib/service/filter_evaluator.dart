import '../model/activation_window.dart';
import '../model/completion.dart';
import '../model/filter.dart';
import '../model/lakshya_graph.dart';
import '../model/node.dart';
import 'graph_traversal.dart';

/// Applies a [Filter] to a [LakshyaGraph] and returns the matching nodes in
/// stable original-order.
///
/// The order of filter passes is deliberately progressive: ancestor scope
/// first (narrows search), then status type / ongoing / free text (per-node
/// predicates), and `onlyLeaves` last so leaf-ness is computed against the
/// *filtered* subgraph rather than the whole DAG.
class FilterEvaluator {
  FilterEvaluator({required LakshyaGraph graph, required this.now})
      : _graph = graph,
        _traversal = GraphTraversal(graph);

  final LakshyaGraph _graph;
  final GraphTraversal _traversal;
  final DateTime now;

  List<Node> apply(Filter filter) {
    Iterable<Node> candidates = _graph.nodes;

    if (filter.ancestorGoalIds.isNotEmpty) {
      final inScope = <String>{};
      for (final goalId in filter.ancestorGoalIds) {
        inScope.addAll(_traversal.descendantsOf(
          goalId,
          contribution: filter.contribution,
        ));
      }
      candidates = candidates.where((n) => inScope.contains(n.id));
    }

    if (filter.activationKinds.isNotEmpty) {
      final allowed = filter.activationKinds.toSet();
      candidates =
          candidates.where((n) => allowed.contains(n.status.activation.kind));
    }

    if (filter.completionKinds.isNotEmpty) {
      final allowed = filter.completionKinds.toSet();
      candidates = candidates.where((n) {
        final c = n.status.completion;
        final key = c == null ? 'none' : c.kind;
        return allowed.contains(key);
      });
    }

    if (!filter.showTimewiseInactiveTasks) {
      candidates = candidates.where((n) => !_isTimewiseInactive(n));
    }

    if (!filter.showCompletedTasks) {
      candidates = candidates.where((n) => !_isFullyCompleted(n));
    }

    if (filter.onlyOngoing) {
      candidates = candidates.where((n) => n.status.isOngoingAt(now));
    }

    final freeText = filter.freeText?.trim().toLowerCase();
    if (freeText != null && freeText.isNotEmpty) {
      candidates = candidates.where((n) {
        if (n.title.toLowerCase().contains(freeText)) return true;
        final desc = n.description;
        return desc != null && desc.toLowerCase().contains(freeText);
      });
    }

    final list = candidates.toList(growable: false);

    if (filter.onlyLeaves) {
      final scope = list.map((n) => n.id).toSet();
      return list
          .where((n) =>
              n.status.completion != null &&
              _traversal.isLeafIn(n.id, scope: scope))
          .toList(growable: false);
    }

    return list;
  }

  bool _isTimewiseInactive(Node node) {
    final activation = node.status.activation;
    if (activation is BoundedActive && now.isBefore(activation.activeFrom)) {
      return true;
    }
    final completion = node.status.completion;
    if (completion is PeriodicCompletion && !completion.isOpenAt(now)) {
      return true;
    }
    return false;
  }

  bool _isFullyCompleted(Node node) {
    final completion = node.status.completion;
    return switch (completion) {
      OneTimeCompletion() => completion.isCompleted,
      NTimesCompletion() => completion.isExhausted,
      PeriodicCompletion() => false,
      null => false,
    };
  }
}
