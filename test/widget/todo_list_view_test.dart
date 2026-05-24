import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/edge.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/todo_list_view.dart';

Node _n(String id, NodeStatus status,
        {String? title, DateTime? deadline}) =>
    Node(
      id: id,
      title: title ?? id,
      status: status,
      deadline: deadline,
      createdAt: DateTime.utc(2026, 5, 24),
    );

Edge _e(String id, String child, String parent) => Edge(
      id: id,
      childId: child,
      parentId: parent,
      contribution: Contribution.mandatory,
    );

void main() {
  testWidgets('renders ongoing leaf tasks ordered by deadline',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        _n('root', const AlwaysOnStatus()),
        _n('paper', const OneTimeStatus(),
            title: 'Write paper', deadline: DateTime.utc(2026, 5, 26)),
        _n('email', const OneTimeStatus(),
            title: 'Send email', deadline: DateTime.utc(2026, 5, 25)),
        _n('done', OneTimeStatus(completedAt: DateTime.utc(2026, 5, 20)),
            title: 'Already done'),
      ],
      edges: [
        _e('e1', 'paper', 'root'),
        _e('e2', 'email', 'root'),
        _e('e3', 'done', 'root'),
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

    // Verify deadline order: Send email (earlier) appears before Write paper.
    final emailY = tester.getCenter(find.text('Send email')).dy;
    final paperY = tester.getCenter(find.text('Write paper')).dy;
    expect(emailY, lessThan(paperY));
  });

  testWidgets('tapping the checkbox marks the task complete and updates list',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        _n('root', const AlwaysOnStatus()),
        _n('paper', const OneTimeStatus(), title: 'Write paper'),
      ],
      edges: [_e('e1', 'paper', 'root')],
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
    final completed = controller.graph.nodes
        .firstWhere((n) => n.id == 'paper')
        .status as OneTimeStatus;
    expect(completed.isCompleted, isTrue);
  });

  testWidgets('shows an empty-state message when the filter has no matches',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [_n('root', const AlwaysOnStatus())],
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
        filter: const Filter(onlyOngoing: true, onlyLeaves: true,
            statusTypes: [StatusType.oneTime]),
      ),
    ));

    expect(find.text('No tasks match this filter.'), findsOneWidget);
  });
}
