import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/activation_window.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/impact.dart';
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

  testWidgets('unchecking a completed task marks it incomplete again',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode(
          'paper',
          title: 'Write paper',
          status: NodeStatus.oneTime(
            completedAt: DateTime.utc(2026, 5, 24, 9),
          ),
        ),
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
        filter: const Filter(showCompletedTasks: true, onlyLeaves: true),
      ),
    ));

    expect(find.text('Write paper'), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(checkbox.value, isTrue);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    final completion = controller.graph.nodes
        .firstWhere((n) => n.id == 'paper')
        .status
        .completion as OneTimeCompletion;
    expect(completion.isCompleted, isFalse);
    expect(find.text('Write paper'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
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
          completionKinds: [CompletionKindFilter.oneTime],
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

  testWidgets('tree rows can collapse and persist hidden descendants',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('project', title: 'Project'),
        buildNode('task', title: 'Write abstract', status: NodeStatus.oneTime()),
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
        filter: const Filter(),
      ),
    ));

    expect(find.text('Project'), findsOneWidget);
    expect(find.text('Write abstract'), findsOneWidget);

    final projectRow = find.ancestor(
      of: find.text('Project'),
      matching: find.byType(ListTile),
    );
    await tester.tap(find.descendant(
      of: projectRow,
      matching: find.byTooltip('Collapse child tasks'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Write abstract'), findsNothing);
    expect(controller.graph.settings?.collapsedNodeIds, ['project']);

    await tester.pumpWidget(MaterialApp(
      home: TodoListView(
        controller: controller,
        title: 'Test',
        filter: const Filter(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Write abstract'), findsNothing,
        reason: 'collapsed state survives rebuilding the next session view');
  });

  testWidgets('leaf-only view ignores persisted collapsed state',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('project', title: 'Project'),
        buildNode('task', title: 'Write abstract', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'project', to: 'root'),
        buildEdge('e2', from: 'task', to: 'project'),
      ],
      settings: const Settings(collapsedNodeIds: ['project']),
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
    expect(find.byTooltip('Collapse child tasks'), findsNothing);
    expect(find.byTooltip('Expand child tasks'), findsNothing);
  });

  testWidgets('tree rows can move a task under another parent',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'All goals achieved'),
        buildNode('cooperations', title: 'Cooperations'),
        buildNode('department', title: 'XY Department'),
        buildNode('talk', title: 'Talk with Peter', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'cooperations', to: 'root'),
        buildEdge('e2', from: 'department', to: 'cooperations'),
        buildEdge('e3', from: 'talk', to: 'cooperations'),
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

    final talkRow = find.ancestor(
      of: find.text('Talk with Peter'),
      matching: find.byType(ListTile),
    );
    await tester.tap(find.descendant(
      of: talkRow,
      matching: find.byTooltip('Move to another parent'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Move "Talk with Peter" under…'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('XY Department')),
    );
    await tester.pumpAndSettle();

    final moved = controller.graph.edges.firstWhere((e) => e.id == 'e3');
    expect(moved.parentId, 'department');
  });

  testWidgets('future-bounded task shows a schedule icon instead of a checked checkbox',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode(
          'task',
          title: 'Conference prep',
          status: NodeStatus(
            activation: BoundedActive(
              activeFrom: DateTime.utc(2026, 5, 30),
              activeUntil: DateTime.utc(2026, 6, 5),
            ),
            completion: const OneTimeCompletion(),
          ),
        ),
      ],
      edges: [buildEdge('e1', from: 'task', to: 'root')],
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
        filter: const Filter(showTimewiseInactiveTasks: true),
      ),
    ));

    final rowFinder = find.ancestor(
      of: find.text('Conference prep'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: rowFinder,
        matching: find.byIcon(Icons.schedule_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rowFinder, matching: find.byType(Checkbox)),
      findsNothing,
    );
  });

  testWidgets('future and cooling-down tasks are hidden by default but can be shown',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode(
          'future',
          title: 'Conference prep',
          status: NodeStatus(
            activation: BoundedActive(
              activeFrom: DateTime.utc(2026, 5, 30),
              activeUntil: DateTime.utc(2026, 6, 5),
            ),
            completion: const OneTimeCompletion(),
          ),
        ),
        buildNode(
          'cooldown',
          title: 'Push day',
          status: NodeStatus.periodic(
            intervalDaysSinceLastCompletion: 3,
            lastCompletedAt: DateTime.utc(2026, 5, 22, 18),
          ),
        ),
      ],
      edges: [
        buildEdge('e1', from: 'future', to: 'root'),
        buildEdge('e2', from: 'cooldown', to: 'root'),
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
        nowFactory: () => DateTime.utc(2026, 5, 24, 12),
      ),
    ));

    expect(find.text('Conference prep'), findsNothing);
    expect(find.text('Push day'), findsNothing);

    await tester.tap(find.byTooltip('Filter & save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show timewise inactive tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Conference prep'), findsOneWidget);
    expect(find.text('Push day'), findsOneWidget);
  });

  testWidgets('completed tasks are hidden by default and can be shown via the drawer',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode(
          'done',
          title: 'Already done',
          status: NodeStatus.oneTime(
            completedAt: DateTime.utc(2026, 5, 20),
          ),
        ),
        buildNode(
          'open',
          title: 'Still open',
          status: NodeStatus.oneTime(),
        ),
      ],
      edges: [
        buildEdge('e1', from: 'done', to: 'root'),
        buildEdge('e2', from: 'open', to: 'root'),
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

    // Default: completed tasks are hidden.
    expect(find.text('Already done'), findsNothing);
    expect(find.text('Still open'), findsOneWidget);

    // Toggle the drawer switch to show them.
    await tester.tap(find.byTooltip('Filter & save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show completed tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Already done'), findsOneWidget);
    expect(find.text('Still open'), findsOneWidget);
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

  testWidgets('more options keeps the quick-add title, status, impact, and deadline draft',
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
    await tester.tap(find.byType(DropdownButtonFormField<Impact?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical').last);
    await tester.pumpAndSettle();
    final pickDeadline = find.text('Pick deadline');
    await tester.ensureVisible(pickDeadline);
    await tester.pumpAndSettle();
    await tester.tap(pickDeadline);
    await tester.pumpAndSettle();
    await tester.tap(find.text('28'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final moreOptions = find.widgetWithText(TextButton, 'More options…');
    await tester.ensureVisible(moreOptions);
    await tester.pumpAndSettle();
    await tester.tap(moreOptions);
    await tester.pumpAndSettle();

    expect(find.byType(AddNodeView), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Push day'), findsOneWidget);
    expect(
      find.text('Recurring (period from last completion)'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, '3'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final added = controller.graph.nodes.firstWhere((n) => n.title == 'Push day');
    expect(added.impact, Impact.critical);
    expect(added.deadline, DateTime(2026, 5, 28));
    expect(
      added.status.completion,
      const PeriodicCompletion(intervalDaysSinceLastCompletion: 3),
    );
  });

  testWidgets('more options keeps the quick-add contribution draft',
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

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Notes');
    await tester.tap(find.text('Helpful'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'More options…'));
    await tester.pumpAndSettle();

    final contributionField = tester.widget<DropdownButtonFormField<Contribution>>(
      find.byType(DropdownButtonFormField<Contribution>).first,
    );
    expect(contributionField.initialValue, Contribution.helpful);
  });
}
