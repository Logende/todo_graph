import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/todo_list_view.dart';

import '../support/builders.dart';

void main() {
  testWidgets('renders ongoing leaf tasks ordered by deadline',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('paper',
            title: 'Write paper',
            status: NodeStatus.oneTime(),
            deadline: DateTime.utc(2026, 5, 26)),
        buildNode('email',
            title: 'Send email',
            status: NodeStatus.oneTime(),
            deadline: DateTime.utc(2026, 5, 25)),
        buildNode('done',
            title: 'Already done',
            status:
                NodeStatus.oneTime(completedAt: DateTime.utc(2026, 5, 20))),
      ],
      edges: [
        buildEdge('e1', from: 'paper', to: 'root'),
        buildEdge('e2', from: 'email', to: 'root'),
        buildEdge('e3', from: 'done', to: 'root'),
      ],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );

    await tester.pumpWidget(MaterialApp(
      home: TodoListView(
        controller: controller,
        title: 'Test',
        filter: const Filter(onlyOngoing: true, onlyLeaves: true),
      ),
    ));

    expect(find.text('Send email'), findsOneWidget);
    expect(find.text('Write paper'), findsOneWidget);
    expect(find.text('Already done'), findsNothing);

    final emailY = tester.getCenter(find.text('Send email')).dy;
    final paperY = tester.getCenter(find.text('Write paper')).dy;
    expect(emailY, lessThan(paperY));
  });

  testWidgets('tapping the checkbox marks the task complete and updates list',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('paper',
            title: 'Write paper', status: NodeStatus.oneTime()),
      ],
      edges: [buildEdge('e1', from: 'paper', to: 'root')],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );

    await tester.pumpWidget(MaterialApp(
      home: TodoListView(
        controller: controller,
        title: 'Test',
        filter: const Filter(onlyOngoing: true, onlyLeaves: true),
      ),
    ));

    expect(find.text('Write paper'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.text('Write paper'), findsNothing,
        reason:
            'completed one_time leaves the onlyOngoing filter and disappears');
    final completion = controller.graph.nodes
        .firstWhere((n) => n.id == 'paper')
        .status
        .completion as OneTimeCompletion;
    expect(completion.isCompleted, isTrue);
  });

  testWidgets('shows an empty-state message when the filter has no matches',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [buildNode('root')],
      edges: const [],
    );
    final controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator(),
      clock: () => DateTime.utc(2026, 5, 24),
    );

    await tester.pumpWidget(MaterialApp(
      home: TodoListView(
        controller: controller,
        title: 'Test',
        filter: const Filter(
          onlyOngoing: true,
          onlyLeaves: true,
          completionKinds: ['one_time'],
        ),
      ),
    ));

    expect(find.text('No tasks match this filter.'), findsOneWidget);
  });
}
