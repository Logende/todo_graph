import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/model/priority_pin.dart';
import 'package:lakshya/service/node_ordering.dart';

Node _n(
  String id, {
  DateTime? deadline,
  double? priority,
  double? positiveImpact,
  DateTime? createdAt,
}) =>
    Node(
      id: id,
      title: id,
      status: const AlwaysOnStatus(),
      deadline: deadline,
      priority: priority,
      positiveImpact: positiveImpact,
      createdAt: createdAt ?? DateTime.utc(2026, 5, 24),
    );

void main() {
  group('NodeOrdering.defaultOrder', () {
    test('empty input returns empty', () {
      final result = const NodeOrdering().defaultOrder(const []);
      expect(result, isEmpty);
    });

    test('sorts by deadline ascending, missing deadline goes last', () {
      final nodes = [
        _n('no-dl'),
        _n('soon', deadline: DateTime.utc(2026, 5, 26)),
        _n('later', deadline: DateTime.utc(2026, 6, 1)),
      ];
      final result = const NodeOrdering().defaultOrder(nodes);
      expect(result.map((n) => n.id), equals(['soon', 'later', 'no-dl']));
    });

    test('breaks deadline ties by priority desc, then impact desc', () {
      final deadline = DateTime.utc(2026, 5, 26);
      final nodes = [
        _n('a', deadline: deadline, priority: 1, positiveImpact: 5),
        _n('b', deadline: deadline, priority: 5, positiveImpact: 1),
        _n('c', deadline: deadline, priority: 5, positiveImpact: 9),
      ];
      final result = const NodeOrdering().defaultOrder(nodes);
      expect(result.map((n) => n.id), equals(['c', 'b', 'a']));
    });

    test('falls back to createdAt ascending as a stable tiebreaker', () {
      final nodes = [
        _n('newer', createdAt: DateTime.utc(2026, 5, 24)),
        _n('older', createdAt: DateTime.utc(2026, 5, 20)),
      ];
      final result = const NodeOrdering().defaultOrder(nodes);
      expect(result.map((n) => n.id), equals(['older', 'newer']));
    });
  });

  group('NodeOrdering with priority pins', () {
    test('a single pin lifts the higher node above the lower one', () {
      final nodes = [
        _n('a', priority: 10), // would come first by priority
        _n('b', priority: 1),
      ];
      const pins = [PriorityPin(higherId: 'b', lowerId: 'a')];
      final result =
          const NodeOrdering().defaultOrder(nodes, priorityPins: pins);
      expect(result.map((n) => n.id), equals(['b', 'a']));
    });

    test('chained pins (a > b > c) form a consistent order', () {
      final nodes = [
        _n('c', priority: 100),
        _n('b', priority: 50),
        _n('a', priority: 1),
      ];
      const pins = [
        PriorityPin(higherId: 'a', lowerId: 'b'),
        PriorityPin(higherId: 'b', lowerId: 'c'),
      ];
      final result =
          const NodeOrdering().defaultOrder(nodes, priorityPins: pins);
      expect(result.map((n) => n.id), equals(['a', 'b', 'c']));
    });

    test('a pin referencing unknown ids is ignored, not crashed on', () {
      final nodes = [_n('a', priority: 1), _n('b', priority: 2)];
      const pins = [PriorityPin(higherId: 'ghost', lowerId: 'a')];
      final result =
          const NodeOrdering().defaultOrder(nodes, priorityPins: pins);
      expect(result.map((n) => n.id), equals(['b', 'a']));
    });
  });
}
