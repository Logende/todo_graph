import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/service/filter_evaluator.dart';

import '../support/builders.dart';

Node _alwaysOn(String id, {String? description}) =>
    buildNode(id, description: description);

Node _oneTime(String id, {DateTime? completedAt}) =>
    buildNode(id, status: NodeStatus.oneTime(completedAt: completedAt));

Node _periodic(String id,
        {required int interval, DateTime? lastCompletedAt}) =>
    buildNode(id,
        status: NodeStatus.periodic(
          intervalDaysSinceLastCompletion: interval,
          lastCompletedAt: lastCompletedAt,
        ));

void main() {
  group('FilterEvaluator', () {
    late LakshyaGraph graph;
    final now = DateTime.utc(2026, 5, 24, 12);

    setUp(() {
      graph = LakshyaGraph(
        nodes: [
          _alwaysOn('root'),
          _alwaysOn('health'),
          _alwaysOn('work'),
          _periodic('pushday',
              interval: 3, lastCompletedAt: DateTime.utc(2026, 5, 22, 18)),
          _oneTime('write-paper'),
          _oneTime('done-thing', completedAt: DateTime.utc(2026, 5, 20)),
          _alwaysOn('llm-paper', description: 'urgent llm paper'),
        ],
        edges: [
          buildEdge('e1', from: 'health', to: 'root'),
          buildEdge('e2', from: 'work', to: 'root'),
          buildEdge('e3', from: 'pushday', to: 'health'),
          buildEdge('e4', from: 'write-paper', to: 'work'),
          buildEdge('e5', from: 'done-thing', to: 'work'),
          buildEdge('e6', from: 'llm-paper', to: 'write-paper', contribution: Contribution.helpful),
        ],
      );
    });

    test('an empty filter keeps every node', () {
      final result =
          FilterEvaluator(graph: graph, now: now).apply(const Filter());
      expect(result.map((n) => n.id),
          containsAll(graph.nodes.map((n) => n.id)));
      expect(result, hasLength(graph.nodes.length));
    });

    test('ancestorGoalIds restricts to descendants of the goal', () {
      final result = FilterEvaluator(graph: graph, now: now)
          .apply(const Filter(ancestorGoalIds: ['health']));
      expect(result.map((n) => n.id), equals(['pushday']));
    });

    test('multiple ancestorGoalIds union descendants', () {
      final result = FilterEvaluator(graph: graph, now: now).apply(
        const Filter(ancestorGoalIds: ['health', 'work']),
      );
      expect(
        result.map((n) => n.id).toSet(),
        equals({'pushday', 'write-paper', 'done-thing', 'llm-paper'}),
      );
    });

    test('contribution=mandatory excludes nodes reached via helpful edges',
        () {
      final result = FilterEvaluator(graph: graph, now: now).apply(
        const Filter(
          ancestorGoalIds: ['work'],
          contribution: FilterContribution.mandatory,
        ),
      );
      expect(
        result.map((n) => n.id).toSet(),
        equals({'write-paper', 'done-thing'}),
      );
    });

    test('completionKinds restricts by completion kind', () {
      final result = FilterEvaluator(graph: graph, now: now)
          .apply(const Filter(completionKinds: ['periodic']));
      expect(result.map((n) => n.id), equals(['pushday']));
    });

    test('completionKinds=["none"] keeps background goals', () {
      final result = FilterEvaluator(graph: graph, now: now)
          .apply(const Filter(completionKinds: ['none']));
      expect(result.map((n) => n.id).toSet(),
          equals({'root', 'health', 'work', 'llm-paper'}));
    });

    test('onlyOngoing drops completed one_time and pre-cool-down periodic',
        () {
      // pushday completed at 2026-05-22 with interval 3 -> next due 2026-05-25
      // at 18:00; "now" is 2026-05-24 12:00 -> still in cool-down -> dropped.
      final result =
          FilterEvaluator(graph: graph, now: now).apply(const Filter(
        onlyOngoing: true,
      ));
      final ids = result.map((n) => n.id).toSet();
      expect(ids.contains('done-thing'), isFalse,
          reason: 'one_time with completedAt set is not ongoing');
      expect(ids.contains('pushday'), isFalse,
          reason: 'periodic still in cool-down window');
      expect(ids.contains('write-paper'), isTrue);
      expect(ids.contains('health'), isTrue,
          reason: 'always_on is always ongoing');
    });

    test('onlyLeaves keeps only leaves inside the filtered subgraph', () {
      // Restrict to ancestors=work and onlyLeaves: among {write-paper,
      // done-thing, llm-paper}, llm-paper is structurally a leaf under
      // write-paper but is a background goal, so only the actionable
      // done-thing remains. write-paper has one child (llm-paper) which is
      // in the scope, so it is NOT a leaf in scope.
      final result = FilterEvaluator(graph: graph, now: now).apply(
        const Filter(ancestorGoalIds: ['work'], onlyLeaves: true),
      );
      expect(result.map((n) => n.id).toSet(), equals({'done-thing'}));
    });

    test('onlyLeaves excludes background goals even when they are structural leaves',
        () {
      final result =
          FilterEvaluator(graph: graph, now: now).apply(const Filter(
        onlyLeaves: true,
      ));
      expect(result.map((n) => n.id).toSet(),
          equals({'pushday', 'done-thing'}));
      expect(result.any((n) => n.id == 'llm-paper'), isFalse,
          reason: 'background goals are not actionable leaf tasks');
    });

    test('freeText matches title and description, case-insensitive', () {
      final byTitle = FilterEvaluator(graph: graph, now: now)
          .apply(const Filter(freeText: 'PUSH'));
      expect(byTitle.map((n) => n.id), equals(['pushday']));

      final byDescription = FilterEvaluator(graph: graph, now: now)
          .apply(const Filter(freeText: 'urgent'));
      expect(byDescription.map((n) => n.id), equals(['llm-paper']));
    });

    test('combined filter narrows progressively', () {
      final result = FilterEvaluator(graph: graph, now: now).apply(
        const Filter(
          ancestorGoalIds: ['work'],
          contribution: FilterContribution.mandatory,
          onlyOngoing: true,
          onlyLeaves: true,
        ),
      );
      expect(result.map((n) => n.id).toSet(), equals({'write-paper'}));
    });
  });
}
