import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/graph_canvas_view.dart';

import '../support/builders.dart';

GraphController _controllerWith(LakshyaGraph graph) => GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator('id'),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );

void main() {
  testWidgets('renders node titles in the graph canvas', (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'All goals achieved'),
        buildNode('health', title: 'Health'),
      ],
      edges: [buildEdge('e1', from: 'health', to: 'root')],
    );
    final c = _controllerWith(graph);

    await tester.pumpWidget(MaterialApp(
      home: GraphCanvasView(controller: c),
    ));

    expect(find.text('All goals achieved'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
  });

  testWidgets('completed nodes show line-through decoration', (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('done',
            title: 'Done task',
            status: NodeStatus.oneTime(
                completedAt: DateTime.utc(2026, 5, 20))),
      ],
      edges: const [],
    );
    final c = _controllerWith(graph);

    await tester.pumpWidget(MaterialApp(
      home: GraphCanvasView(controller: c),
    ));

    final textWidget = tester.widget<Text>(find.text('Done task'));
    expect(textWidget.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('shows empty state when the graph has no nodes',
      (tester) async {
    final c = _controllerWith(const LakshyaGraph.empty());

    await tester.pumpWidget(MaterialApp(
      home: GraphCanvasView(controller: c),
    ));

    expect(find.textContaining('No nodes'), findsOneWidget);
  });

  testWidgets('non-leaf nodes show a collapse toggle', (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'Root'),
        buildNode('child', title: 'Child'),
      ],
      edges: [buildEdge('e1', from: 'child', to: 'root')],
    );
    final c = _controllerWith(graph);

    await tester.pumpWidget(MaterialApp(
      home: GraphCanvasView(controller: c),
    ));

    expect(find.text('Hide children'), findsOneWidget);
    expect(find.text('Show children'), findsNothing);
  });
}
