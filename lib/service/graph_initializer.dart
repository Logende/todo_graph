import '../model/lakshya_graph.dart';
import '../model/node.dart';
import '../model/node_status.dart';
import '../model/settings.dart';
import 'id_generator.dart';

typedef Clock = DateTime Function();

/// Builds the initial empty [LakshyaGraph] on first launch (or when the user
/// resets the app). The graph always contains the top-level "All goals
/// achieved" root node so every newly-added goal has somewhere to attach.
class GraphInitializer {
  GraphInitializer({required this.idGenerator, required this.clock});

  final IdGenerator idGenerator;
  final Clock clock;

  static const String rootTitle = 'All goals achieved';

  LakshyaGraph emptyGraph() {
    final now = clock();
    final root = Node(
      id: idGenerator.next(),
      title: rootTitle,
      status: NodeStatus.alwaysOnBackground,
      createdAt: now,
    );
    return LakshyaGraph(
      nodes: [root],
      edges: const [],
      settings: Settings(rootNodeId: root.id),
    );
  }
}
