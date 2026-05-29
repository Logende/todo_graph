import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/filter_preset.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/hybrid_hierarchy_view.dart';

import '../support/builders.dart';

GraphController _controllerWith(LakshyaGraph graph) => GraphController(
  initial: graph,
  save: (_) async {},
  idGenerator: SequentialIdGenerator('id'),
  clock: () => DateTime.utc(2026, 5, 24, 12),
);

void main() {
  testWidgets('renders leaves left of their parent levels', (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'Root'),
        buildNode('project', title: 'Project'),
        buildNode(
          'task',
          title: 'Write abstract',
          status: NodeStatus.oneTime(),
        ),
      ],
      edges: [
        buildEdge('e1', from: 'project', to: 'root'),
        buildEdge('e2', from: 'task', to: 'project'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HybridHierarchyView(controller: _controllerWith(graph)),
      ),
    );
    await tester.pump();

    expect(find.text('Leaves'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Root Goal'), findsOneWidget);
    expect(find.text('Write abstract'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('Root'), findsOneWidget);

    final taskX = tester.getTopLeft(find.text('Write abstract')).dx;
    final projectX = tester.getTopLeft(find.text('Project')).dx;
    final rootX = tester.getTopLeft(find.text('Root')).dx;
    expect(taskX, lessThan(projectX));
    expect(projectX, lessThan(rootX));
  });

  testWidgets('root-first view settings place the root goal on the left', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'Root'),
        buildNode('project', title: 'Project'),
        buildNode(
          'task',
          title: 'Write abstract',
          status: NodeStatus.oneTime(),
        ),
      ],
      edges: [
        buildEdge('e1', from: 'project', to: 'root'),
        buildEdge('e2', from: 'task', to: 'project'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HybridHierarchyView(
          controller: _controllerWith(graph),
          viewSettings: const ExplorerViewSettings(
            displayMode: ExplorerDisplayMode.graph,
            graphFlow: ExplorerGraphFlow.rootToLeaves,
          ),
        ),
      ),
    );
    await tester.pump();

    // The root-flow direction comes from saved view settings; there is no
    // visible toggle for it in the graph controls.
    expect(find.byTooltip('Start from root'), findsNothing);

    expect(find.text('Root Goal'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Leaves'), findsOneWidget);

    final rootX = tester.getTopLeft(find.text('Root')).dx;
    final projectX = tester.getTopLeft(find.text('Project')).dx;
    final taskX = tester.getTopLeft(find.text('Write abstract')).dx;
    expect(rootX, lessThan(projectX));
    expect(projectX, lessThan(taskX));
  });

  testWidgets('multi-parent leaf appears once and both parents render', (
    tester,
  ) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('work', title: 'Work'),
        buildNode('health', title: 'Health'),
        buildNode(
          'task',
          title: 'Walk to office',
          status: NodeStatus.oneTime(),
        ),
      ],
      edges: [
        buildEdge('e1', from: 'task', to: 'work'),
        buildEdge('e2', from: 'task', to: 'health'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HybridHierarchyView(controller: _controllerWith(graph)),
      ),
    );
    await tester.pump();

    expect(find.text('Walk to office'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
  });

  testWidgets('scoped hybrid view includes the selected scope node', (
    tester,
  ) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'Root'),
        buildNode('project', title: 'Project'),
        buildNode(
          'task',
          title: 'Write abstract',
          status: NodeStatus.oneTime(),
        ),
      ],
      edges: [
        buildEdge('e1', from: 'project', to: 'root'),
        buildEdge('e2', from: 'task', to: 'project'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HybridHierarchyView(
          controller: _controllerWith(graph),
          filter: const Filter(ancestorGoalIds: ['project']),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Project'), findsOneWidget);
    expect(find.text('Write abstract'), findsOneWidget);
    expect(find.text('Root'), findsNothing);
  });

  testWidgets('nodes with children can collapse and expand child tasks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'Root'),
        buildNode('project', title: 'Project'),
        buildNode(
          'task',
          title: 'Write abstract',
          status: NodeStatus.oneTime(),
        ),
      ],
      edges: [
        buildEdge('e1', from: 'project', to: 'root'),
        buildEdge('e2', from: 'task', to: 'project'),
      ],
    );
    final controller = _controllerWith(graph);

    await tester.pumpWidget(
      MaterialApp(home: HybridHierarchyView(controller: controller)),
    );
    await tester.pump();

    expect(find.text('Write abstract'), findsOneWidget);
    await tester.tap(find.byTooltip('Next level'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hide child tasks').first);
    await tester.pumpAndSettle();

    expect(controller.graph.settings?.collapsedNodeIds, contains('project'));
    expect(find.text('Write abstract'), findsNothing);
    expect(find.text('Project'), findsOneWidget);

    await tester.tap(find.byTooltip('Show child tasks').first);
    await tester.pumpAndSettle();

    expect(find.text('Write abstract'), findsOneWidget);
  });

  testWidgets('placement toggle switches between centered and packed modes', (
    tester,
  ) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('parent', title: 'Parent'),
        buildNode('a', title: 'A', status: NodeStatus.oneTime()),
      ],
      edges: [buildEdge('e1', from: 'a', to: 'parent')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HybridHierarchyView(controller: _controllerWith(graph)),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Leaves'), findsWidgets);
    expect(find.byTooltip('Pack levels as lists'), findsOneWidget);
    expect(find.byTooltip('Fit current level'), findsOneWidget);

    await tester.tap(find.byTooltip('Pack levels as lists'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Center parents over children'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('graph mode hides leaves-only controls', (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'Root'),
        buildNode('task', title: 'Task', status: NodeStatus.oneTime()),
      ],
      edges: [buildEdge('e1', from: 'task', to: 'root')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HybridHierarchyView(controller: _controllerWith(graph)),
      ),
    );
    await tester.pump();

    expect(
      find.byTooltip('Show leaves only'),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();

    expect(find.text('Goal scope'), findsOneWidget);
    expect(find.text('Show completed tasks'), findsOneWidget);
    expect(find.text('Only leaves'), findsNothing);
    expect(find.text('Save as tile'), findsOneWidget);

    final drawerScrollable = find
        .descendant(of: find.byType(Drawer), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('Contribution'),
      220,
      scrollable: drawerScrollable,
    );
    expect(find.text('Only ongoing'), findsOneWidget);
    expect(find.text('Contribution'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Activation kinds'),
      220,
      scrollable: drawerScrollable,
    );
    expect(find.text('Completion kinds'), findsOneWidget);
    expect(find.text('Activation kinds'), findsOneWidget);
  });

  testWidgets('tree-list mode keeps leaves-only controls', (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'Root'),
        buildNode('task', title: 'Task', status: NodeStatus.oneTime()),
      ],
      edges: [buildEdge('e1', from: 'task', to: 'root')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HybridHierarchyView(controller: _controllerWith(graph)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Show tree list'));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Show leaves only'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();

    final drawerScrollable = find
        .descendant(of: find.byType(Drawer), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('Only leaves'),
      120,
      scrollable: drawerScrollable,
    );
    expect(find.text('Only leaves'), findsOneWidget);
  });

  testWidgets('narrow screens keep graph controls reachable', (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final graph = LakshyaGraph(
      nodes: [
        buildNode('root', title: 'Root'),
        buildNode('task', title: 'Task', status: NodeStatus.oneTime()),
      ],
      edges: [buildEdge('e1', from: 'task', to: 'root')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HybridHierarchyView(controller: _controllerWith(graph)),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Previous level'), findsOneWidget);
    expect(find.byTooltip('Next level'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byTooltip('Filter'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Zoom out'), findsOneWidget);
    expect(find.text('Zoom in'), findsOneWidget);
    expect(find.text('Fit current level'), findsOneWidget);
  });
}
