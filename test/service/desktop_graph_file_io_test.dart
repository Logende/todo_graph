import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/service/desktop_graph_file_io.dart';
import 'package:lakshya/service/graph_io.dart';
import 'package:lakshya/service/schema_validator.dart';

import '../support/builders.dart';

void main() {
  late SchemaValidator validator;
  late Directory tempDir;

  setUpAll(() {
    final schemaText =
        File('schema/lakshya.schema.json').readAsStringSync();
    validator = SchemaValidator.fromString(schemaText);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lakshya_file_io_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('exportToFile writes a schema-valid JSON document', () async {
    final path = '${tempDir.path}/export.json';
    final graph = LakshyaGraph(
      nodes: [buildNode('root', title: 'All goals achieved')],
      edges: const [],
    );
    final io = DesktopGraphFileIo(graphIo: GraphIo(validator: validator));

    await io.exportToFile(graph: graph, path: path);

    final exported = File(path).readAsStringSync();
    expect(exported, contains('"schemaVersion": $kCurrentSchemaVersion'));
    expect(GraphIo(validator: validator).importFromJson(exported), equals(graph));
  });

  test('importFromFile reads and validates the JSON document', () async {
    final path = '${tempDir.path}/import.json';
    final graph = LakshyaGraph(
      nodes: [buildNode('root'), buildNode('task')],
      edges: const [],
    );
    File(path).writeAsStringSync(GraphIo(validator: validator).exportToJson(graph));
    final io = DesktopGraphFileIo(graphIo: GraphIo(validator: validator));

    final imported = await io.importFromFile(path);

    expect(imported, equals(graph));
  });
}
