import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/app/graph_controller.dart';
import 'package:lakshya/model/attachment.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node_notification_settings.dart';
import 'package:lakshya/model/node_relationship.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/external_url_opener.dart';
import 'package:lakshya/service/id_generator.dart';
import 'package:lakshya/view/node_detail_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../support/builders.dart';

GraphController _controllerWith(LakshyaGraph graph) => GraphController(
      initial: graph,
      save: (_) async {},
      idGenerator: SequentialIdGenerator('id'),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );

Future<void> _pumpDetailFor(
  WidgetTester tester,
  GraphController controller,
  String nodeId,
  {ExternalUrlOpener urlOpener = const ExternalUrlOpener()}
) async {
  await tester.pumpWidget(MaterialApp(
    home: NodeDetailView(
      controller: controller,
      nodeId: nodeId,
      urlOpener: urlOpener,
    ),
  ));
}

Finder _notificationDropdown() => find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<bool?> &&
          widget.decoration.labelText == 'Periodic reopen notifications',
    );

void main() {
  testWidgets('renders parents and relationships of the selected node',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('paper-a', title: 'Paper A', status: NodeStatus.oneTime()),
        buildNode('paper-b', title: 'Paper B', status: NodeStatus.oneTime()),
        buildNode('paper-c', title: 'Paper C', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'paper-a', to: 'root'),
        buildEdge('e2', from: 'paper-c', to: 'paper-a'),
      ],
      relationships: const [
        NodeRelationship(
          id: 'r1',
          fromNodeId: 'paper-a',
          toNodeId: 'paper-b',
          kind: RelationshipKind.alternativeTo,
        ),
      ],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(tester, controller, 'paper-a');

    expect(find.text('Paper A'), findsOneWidget);
    expect(find.text('Parent goals / contexts (1)'), findsOneWidget);
    expect(find.text('root'), findsOneWidget);
    expect(find.text('Child tasks / dependents (1)'), findsOneWidget);
    expect(find.text('Paper C'), findsOneWidget);
    expect(find.text('Other relationships (1)'), findsOneWidget);
    expect(find.textContaining('Paper A'), findsWidgets);
    expect(find.textContaining('Paper B'), findsWidgets);
  });

  testWidgets('multiple parents are shown as a real list', (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('project-a', title: 'Project A'),
        buildNode('project-b', title: 'Project B'),
        buildNode('task', title: 'Shared task', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'project-a', to: 'root'),
        buildEdge('e2', from: 'project-b', to: 'root'),
        buildEdge('e3', from: 'task', to: 'project-a'),
        buildEdge('e4', from: 'task', to: 'project-b'),
      ],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(tester, controller, 'task');

    expect(find.text('Parent goals / contexts (2)'), findsOneWidget);
    expect(find.text('Project A'), findsOneWidget);
    expect(find.text('Project B'), findsOneWidget);
  });

  testWidgets('removing a relationship updates the list immediately',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [buildNode('a'), buildNode('b')],
      edges: const [],
      relationships: const [
        NodeRelationship(
          id: 'r1',
          fromNodeId: 'a',
          toNodeId: 'b',
          kind: RelationshipKind.moreImportantThan,
        ),
      ],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(tester, controller, 'a');

    expect(find.text('Other relationships (1)'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove this relationship'));
    await tester.pump();
    expect(find.text('Other relationships (0)'), findsOneWidget);
    expect(controller.graph.relationships, isEmpty);
  });

  testWidgets('Delete confirmation removes the node and its edges',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [buildNode('root'), buildNode('a', title: 'A')],
      edges: [buildEdge('e1', from: 'a', to: 'root')],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(tester, controller, 'a');

    await tester.tap(find.byTooltip('Delete this node'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this node?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(controller.graph.nodes.any((n) => n.id == 'a'), isFalse);
    expect(controller.graph.edges.any((e) => e.id == 'e1'), isFalse);
  });

  testWidgets('deleting a node with children can promote the children',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('parent', title: 'Parent'),
        buildNode('child', title: 'Child', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'parent', to: 'root'),
        buildEdge('e2', from: 'child', to: 'parent'),
      ],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(tester, controller, 'parent');

    await tester.tap(find.byTooltip('Delete this node'));
    await tester.pumpAndSettle();
    expect(find.text('Delete node with children?'), findsOneWidget);

    await tester.tap(find.text('Move children up'));
    await tester.pumpAndSettle();

    expect(controller.graph.nodes.any((n) => n.id == 'parent'), isFalse);
    expect(
      controller.graph.edges.any(
        (e) => e.childId == 'child' && e.parentId == 'root',
      ),
      isTrue,
    );
  });

  testWidgets('deleting a node with children can delete the full subtree',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('parent', title: 'Parent'),
        buildNode('child', title: 'Child', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'parent', to: 'root'),
        buildEdge('e2', from: 'child', to: 'parent'),
      ],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(tester, controller, 'parent');

    await tester.tap(find.byTooltip('Delete this node'));
    await tester.pumpAndSettle();
    expect(find.text('Delete node with children?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete all children too'));
    await tester.pumpAndSettle();

    expect(controller.graph.nodes.any((n) => n.id == 'parent'), isFalse);
    expect(controller.graph.nodes.any((n) => n.id == 'child'), isFalse);
  });

  testWidgets('status summary shows inherited deadline when own deadline is unset',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('project',
            title: 'Project',
            deadline: DateTime.utc(2026, 5, 29)),
        buildNode('task',
            title: 'Write abstract', status: NodeStatus.oneTime()),
      ],
      edges: [
        buildEdge('e1', from: 'project', to: 'root'),
        buildEdge('e2', from: 'task', to: 'project'),
      ],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(tester, controller, 'task');

    expect(find.text('Deadline: 2026-05-29 (inherited)'), findsOneWidget);
  });

  testWidgets('edit dialog saves notification override fields', (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('task',
            title: 'Write abstract', status: NodeStatus.oneTime()),
      ],
      edges: [buildEdge('e1', from: 'task', to: 'root')],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(tester, controller, 'task');

    await tester.tap(find.byTooltip('Edit node'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Deadline reminder lead time (hours)',
      ),
      '6',
    );
    await tester.ensureVisible(_notificationDropdown());
    await tester.tap(_notificationDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Always notify').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final updated = controller.graph.nodes.firstWhere((n) => n.id == 'task');
    expect(
      updated.notificationOverride,
      equals(const NodeNotificationSettings(
        deadlineLeadTimeHours: 6,
        notifyOnPeriodicReopen: true,
      )),
    );
  });

  testWidgets('edit dialog can clear an existing notification override',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode(
          'task',
          title: 'Write abstract',
          status: NodeStatus.oneTime(),
        ).copyWith(
          notificationOverride: const NodeNotificationSettings(
            deadlineLeadTimeHours: 6,
            notifyOnPeriodicReopen: false,
          ),
        ),
      ],
      edges: [buildEdge('e1', from: 'task', to: 'root')],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(tester, controller, 'task');

    await tester.tap(find.byTooltip('Edit node'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Deadline reminder lead time (hours)',
      ),
      '',
    );
    await tester.ensureVisible(_notificationDropdown());
    await tester.tap(_notificationDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use global default').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final updated = controller.graph.nodes.firstWhere((n) => n.id == 'task');
    expect(updated.notificationOverride, isNull);
  });

  testWidgets('can add a reminder-time attachment from the detail view',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode('task', title: 'Write abstract', status: NodeStatus.oneTime()),
      ],
      edges: [buildEdge('e1', from: 'task', to: 'root')],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(tester, controller, 'task');

    await tester.tap(find.byTooltip('Add attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add reminder time'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Label (optional)'), 'Follow up');
    await tester.tap(find.widgetWithText(FilledButton, 'Attach'));
    await tester.pumpAndSettle();

    final updated = controller.graph.nodes.firstWhere((n) => n.id == 'task');
    expect(updated.attachments.single, isA<TimeTriggerAttachment>());
    expect(
      (updated.attachments.single as TimeTriggerAttachment).label,
      'Follow up',
    );
  });

  testWidgets('URL attachments can be copied from the detail view',
      (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode(
          'task',
          title: 'Write abstract',
          status: NodeStatus.oneTime(),
        ).copyWith(
          attachments: const [
            UrlAttachment(url: 'https://example.com', label: 'Reference'),
          ],
        ),
      ],
      edges: [buildEdge('e1', from: 'task', to: 'root')],
    );
    final controller = _controllerWith(graph);

    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await _pumpDetailFor(tester, controller, 'task');

    await tester.tap(find.byTooltip('Copy URL'));
    await tester.pumpAndSettle();

    expect(clipboardText, 'https://example.com');
  });

  testWidgets('URL open failures are shown as a dialog', (tester) async {
    final graph = LakshyaGraph(
      nodes: [
        buildNode('root'),
        buildNode(
          'task',
          title: 'Write abstract',
          status: NodeStatus.oneTime(),
        ).copyWith(
          attachments: const [
            UrlAttachment(url: 'https://example.com', label: 'Reference'),
          ],
        ),
      ],
      edges: [buildEdge('e1', from: 'task', to: 'root')],
    );
    final controller = _controllerWith(graph);

    await _pumpDetailFor(
      tester,
      controller,
      'task',
      urlOpener: ExternalUrlOpener(
        launch: (_, {mode = LaunchMode.platformDefault, webViewConfiguration = const WebViewConfiguration(), browserConfiguration = const BrowserConfiguration(), webOnlyWindowName}) async => false,
      ),
    );

    await tester.tap(find.byTooltip('Open URL'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open URL'), findsOneWidget);
    expect(
      find.textContaining('No application is registered to open this URL'),
      findsOneWidget,
    );
  });
}
