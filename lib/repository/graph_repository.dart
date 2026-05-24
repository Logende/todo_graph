import '../model/lakshya_graph.dart';

/// Persistence interface for the Lakshya graph.
///
/// The whole graph is treated as one document — load and save replace it
/// atomically. Implementations decide where the document lives (local file,
/// cloud sync, in-memory for tests).
abstract class GraphRepository {
  /// Reads the persisted graph.
  ///
  /// Returns `null` if no graph has ever been persisted. Callers decide
  /// whether to bootstrap an empty graph in that case.
  Future<LakshyaGraph?> load();

  /// Writes the graph, overwriting any previously persisted version.
  Future<void> save(LakshyaGraph graph);
}
