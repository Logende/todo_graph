import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/model/settings.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/add_node_view.dart';
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

  testWidgets('shows inherited deadline on a leaf row when own deadline is unset',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('project',
            title: 'Project',
            deadline: DateTime.utc(2026, 5, 28)),
        buildNode('task',
            title: 'Write abstract', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'project', to: 'root'),
        buildEdge('e2', from: 'task', to: 'project'),
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
        filter: const Filter(onlyLeaves: true),
      ),
    ));

    expect(find.text('Write abstract'), findsOneWidget);
    expect(find.text('Due 2026-05-28 (inherited)'), findsOneWidget);
  });

  testWidgets('only leaves hides background goals that cannot be checked off',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('health', title: 'Health'),
        buildNode('task', title: 'Stretch', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'health', to: 'root'),
        buildEdge('e2', from: 'task', to: 'root'),
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
        filter: const Filter(onlyLeaves: true),
      ),
    ));

    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Health'), findsNothing);
  });

  testWidgets('filter drawer goal scope picks an ancestor goal',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'All goals achieved'),
        buildNode('health', title: 'Health'),
        buildNode('work', title: 'Work'),
        buildNode('stretch', title: 'Stretch', status: NodeStatus.oneTime()),
        buildNode('paper', title: 'Write paper', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'health', to: 'root'),
        buildEdge('e2', from: 'work', to: 'root'),
        buildEdge('e3', from: 'stretch', to: 'health'),
        buildEdge('e4', from: 'paper', to: 'work'),
      ],
      settings: const Settings(rootNodeId: 'root'),
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
        filter: const Filter(),
      ),
    ));

    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Write paper'), findsOneWidget);

    await tester.tap(find.byTooltip('Filter & save'));
    await tester.pumpAndSettle();

    expect(find.text('Goal scope'), findsOneWidget);
    final drawer = find.byType(Drawer);
    expect(
      find.descendant(of: drawer, matching: find.text('All goals achieved')),
      findsOneWidget,
    );

    await tester.tap(find.text('Goal scope'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a goal'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Health')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Work')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Stretch')),
      findsNothing,
        reason: 'leaf-only nodes are excluded from the scope picker');

    await tester.tap(find.descendant(of: dialog, matching: find.text('Work')));
    await tester.pumpAndSettle();

    expect(find.text('Write paper'), findsOneWidget);
    expect(find.text('Stretch'), findsNothing);
  });

  testWidgets('more options keeps the quick-add title and status draft',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('task', title: 'Stretch', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'task', to: 'root'),
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
        filter: const Filter(),
      ),
    ));

    await tester.tap(find.byTooltip('Add child').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Push day');
    await tester.tap(find.text('Every 3 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'More options…'));
    await tester.pumpAndSettle();

    expect(find.byType(AddNodeView), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Push day'), findsOneWidget);
    expect(
      find.text('Recurring (period from last completion)'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, '3'), findsOneWidget);
  });
}
