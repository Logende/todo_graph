import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/service/graph_document_migrator.dart';

void main() {
  const migrator = GraphDocumentMigrator();

  group('GraphDocumentMigrator', () {
    test('V1 document without settings migrates to V2', () {
      final input = <String, dynamic>{
        'schemaVersion': 1,
        'nodes': <dynamic>[],
        'edges': <dynamic>[],
      };
      final output = migrator.migrate(input);
      expect(output['schemaVersion'], kCurrentSchemaVersion);
    });

    test('V1 document with settings but no collapsedNodeIds migrates cleanly',
        () {
      final input = <String, dynamic>{
        'schemaVersion': 1,
        'nodes': <dynamic>[],
        'edges': <dynamic>[],
        'settings': <String, dynamic>{'rootNodeId': 'root'},
      };
      final output = migrator.migrate(input);
      expect(output['schemaVersion'], kCurrentSchemaVersion);
      final settings = output['settings'] as Map<String, dynamic>;
      expect(settings['rootNodeId'], 'root');
      expect(settings.containsKey('collapsedNodeIds'), isFalse);
    });

    test('V1 collapsedNodeIds with empty strings and duplicates are cleaned',
        () {
      final input = <String, dynamic>{
        'schemaVersion': 1,
        'nodes': <dynamic>[],
        'edges': <dynamic>[],
        'settings': <String, dynamic>{
          'collapsedNodeIds': ['a', '', 'b', 'a', '  ', 'c'],
        },
      };
      final output = migrator.migrate(input);
      final settings = output['settings'] as Map<String, dynamic>;
      expect(settings['collapsedNodeIds'], equals(['a', 'b', 'c']));
    });

    test('V1 collapsedNodeIds that cleans to empty is removed entirely', () {
      final input = <String, dynamic>{
        'schemaVersion': 1,
        'nodes': <dynamic>[],
        'edges': <dynamic>[],
        'settings': <String, dynamic>{
          'collapsedNodeIds': ['', '  '],
        },
      };
      final output = migrator.migrate(input);
      final settings = output['settings'] as Map<String, dynamic>;
      expect(settings.containsKey('collapsedNodeIds'), isFalse);
    });

    test('document already at current version passes through unchanged', () {
      final input = <String, dynamic>{
        'schemaVersion': kCurrentSchemaVersion,
        'nodes': <dynamic>[],
        'edges': <dynamic>[],
      };
      final output = migrator.migrate(input);
      expect(output['schemaVersion'], kCurrentSchemaVersion);
    });

    test('document with missing schemaVersion defaults to 1 and migrates', () {
      final input = <String, dynamic>{
        'nodes': <dynamic>[],
        'edges': <dynamic>[],
      };
      final output = migrator.migrate(input);
      expect(output['schemaVersion'], kCurrentSchemaVersion);
    });
  });
}
