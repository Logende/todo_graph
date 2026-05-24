import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/completion.dart';
import 'package:lakshya/model/impact.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/add_node_view.dart';

void main() {
  late GraphController controller;

  setUp(() {
    final graph = LakshyaGraph(
      nodes: [
        Node(
          id: 'root',
          title: 'All goals achieved',
          status: NodeStatus.alwaysOnBackground,
          createdAt: DateTime.utc(2026, 5, 24),
        ),
        Node(
          id: 'health',
          title: 'Health',
          status: NodeStatus.alwaysOnBackground,
          createdAt: DateTime.utc(2026, 5, 24),
        ),
      ],
      edges: const [],
    );
    controller = GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator('id'),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );
  });

  testWidgets('cannot submit without a title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AddNodeView(controller: controller, defaultParentId: 'root'),
    ));

    await tester.tap(find.text('Create'));
    await tester.pump();

    expect(find.text('Title is required'), findsOneWidget);
    expect(controller.graph.nodes, hasLength(2));
  });

  testWidgets('creates a one_time child of the selected parent on submit',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AddNodeView(controller: controller, defaultParentId: 'root'),
    ));

    await tester.enterText(find.byType(TextFormField).first, 'Write paper');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(controller.graph.nodes, hasLength(3));
    final added = controller.graph.nodes.last;
    expect(added.title, equals('Write paper'));
    expect(added.status.completion, isA<OneTimeCompletion>());
    expect(controller.graph.edges, hasLength(1));
    expect(controller.graph.edges.single.parentId, equals('root'));
    expect(controller.graph.edges.single.childId, equals(added.id));
  });

  testWidgets('prefills title, status, impact, and deadline from an incoming draft',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AddNodeView(
        controller: controller,
        defaultParentId: 'root',
        initialTitle: 'Push day',
        initialStatus:
            NodeStatus.periodic(intervalDaysSinceLastCompletion: 5),
        initialImpact: Impact.high,
        initialDeadline: DateTime.utc(2026, 5, 30),
      ),
    ));

    expect(find.widgetWithText(TextFormField, 'Push day'), findsOneWidget);
    expect(find.text('Recurring (period from last completion)'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '5'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final added = controller.graph.nodes.last;
    expect(added.title, 'Push day');
    expect(added.impact, Impact.high);
    expect(added.deadline, DateTime.utc(2026, 5, 30));
    expect(
      added.status.completion,
      const PeriodicCompletion(intervalDaysSinceLastCompletion: 5),
    );
  });
}
