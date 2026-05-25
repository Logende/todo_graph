import '../model/lakshya_graph.dart';
import '../repository/graph_repository.dart';
import 'schema_validator.dart';

/// Result of the first-run bootstrap: the graph to hand the controller, plus
/// an optional notice the app should surface.
class BootstrapResult {
  const BootstrapResult({required this.graph, this.recoveryNotice});
  final LakshyaGraph graph;
  final String? recoveryNotice;
}

/// Loads the graph from a repository, or falls back to a seed when the
/// repository is empty or corrupt. Extracted from main.dart so the
/// three-branch logic (load / corrupt-recover / first-run) is unit-testable.
class GraphBootstrapper {
  const GraphBootstrapper();

  Future<BootstrapResult> loadOrBootstrap({
    required GraphRepository repository,
    required LakshyaGraph seed,
  }) async {
    try {
      final loaded = await repository.load();
      if (loaded != null) return BootstrapResult(graph: loaded);
    } on SchemaValidationException catch (e) {
      return BootstrapResult(
        graph: seed,
        recoveryNotice:
            'Your saved graph failed validation; loaded the example seed '
            'instead.\nDetails: ${e.errors.take(2).join("; ")}',
      );
    }
    // First run — seed and persist.
    await repository.save(seed);
    return BootstrapResult(graph: seed);
  }
}
