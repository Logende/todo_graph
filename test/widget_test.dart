import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/app/lakshya_app.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/id_generator.dart';

void main() {
  testWidgets('LakshyaApp boots to the dashboard with the built-in tiles',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        Node(
          id: 'root',
          title: 'All goals achieved',
          status: NodeStatus.alwaysOnBackground,
          createdAt: DateTime.utc(2026, 5, 24),
        ),
      ],
      edges: const [],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    await tester.pumpWidget(LakshyaApp(controller: controller));

    expect(find.text('Lakshya'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Add task'),
        findsOneWidget);
  });
}
