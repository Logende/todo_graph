import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/node_relationship.dart';

void main() {
  group('RelationshipKind', () {
    test('directional kinds are not bidirectional', () {
      expect(RelationshipKind.moreImportantThan.isBidirectional, isFalse);
      expect(RelationshipKind.lessImportantThan.isBidirectional, isFalse);
    });

    test('alternativeTo is bidirectional', () {
      expect(RelationshipKind.alternativeTo.isBidirectional, isTrue);
    });

    test('json values round-trip', () {
      for (final kind in RelationshipKind.values) {
        expect(RelationshipKind.fromJsonValue(kind.toJsonValue()),
            equals(kind));
      }
    });
  });

  group('NodeRelationship.placesAboveB', () {
    test('moreImportantThan places fromNodeId above toNodeId', () {
      const r = NodeRelationship(
        id: 'r1',
        fromNodeId: 'a',
        toNodeId: 'b',
        kind: RelationshipKind.moreImportantThan,
      );
      expect(r.placesAboveB('a', 'b'), isTrue);
      expect(r.placesAboveB('b', 'a'), isFalse);
    });

    test('lessImportantThan places toNodeId above fromNodeId', () {
      const r = NodeRelationship(
        id: 'r1',
        fromNodeId: 'a',
        toNodeId: 'b',
        kind: RelationshipKind.lessImportantThan,
      );
      expect(r.placesAboveB('b', 'a'), isTrue);
      expect(r.placesAboveB('a', 'b'), isFalse);
    });

    test('alternativeTo never places one above the other', () {
      const r = NodeRelationship(
        id: 'r1',
        fromNodeId: 'a',
        toNodeId: 'b',
        kind: RelationshipKind.alternativeTo,
      );
      expect(r.placesAboveB('a', 'b'), isFalse);
      expect(r.placesAboveB('b', 'a'), isFalse);
    });
  });

  group('NodeRelationship.isAlternativeBetween', () {
    const alt = NodeRelationship(
      id: 'r1',
      fromNodeId: 'a',
      toNodeId: 'b',
      kind: RelationshipKind.alternativeTo,
    );
    const directional = NodeRelationship(
      id: 'r2',
      fromNodeId: 'a',
      toNodeId: 'b',
      kind: RelationshipKind.moreImportantThan,
    );

    test('alternativeTo recognises either direction', () {
      expect(alt.isAlternativeBetween('a', 'b'), isTrue);
      expect(alt.isAlternativeBetween('b', 'a'), isTrue);
    });

    test('rejects unrelated nodes', () {
      expect(alt.isAlternativeBetween('a', 'c'), isFalse);
    });

    test('rejects non-alternative kinds', () {
      expect(directional.isAlternativeBetween('a', 'b'), isFalse);
    });
  });

  test('NodeRelationship round-trips through json', () {
    for (final kind in RelationshipKind.values) {
      final original = NodeRelationship(
        id: 'r-${kind.name}',
        fromNodeId: 'a',
        toNodeId: 'b',
        kind: kind,
      );
      expect(
        NodeRelationship.fromJson(original.toJson()),
        equals(original),
      );
    }
  });
}
