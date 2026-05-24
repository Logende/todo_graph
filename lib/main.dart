import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app/graph_controller.dart';
import 'app/lakshya_app.dart';
import 'model/lakshya_graph.dart';
import 'repository/local_json_repository.dart';
import 'service/graph_initializer.dart';
import 'service/id_generator.dart';
import 'service/schema_validator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load and parse the bundled JSON Schema once at startup. Used to gate
  // repository load and JSON import against malformed documents.
  final schemaText =
      await rootBundle.loadString('schema/lakshya.schema.json');
  final validator = SchemaValidator.fromString(schemaText);

  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/lakshya/graph.json');
  final repository =
      LocalJsonRepository(file: file, validator: validator);

  final idGenerator = UuidV4IdGenerator();
  final initializer = GraphInitializer(
    idGenerator: idGenerator,
    clock: DateTime.now,
  );

  LakshyaGraph initial;
  try {
    initial = await repository.load() ?? initializer.emptyGraph();
  } on SchemaValidationException {
    // Corrupted or out-of-version file. For now, bootstrap an empty graph;
    // a recovery flow (rename the old file, surface in UI) is Phase 7 work.
    initial = initializer.emptyGraph();
  }

  final controller = GraphController(
    initial: initial,
    save: repository.save,
    idGenerator: idGenerator,
    clock: DateTime.now,
  );

  // Persist the bootstrap graph immediately so the file exists from now on.
  if ((await repository.load()) == null) {
    await repository.save(initial);
  }

  runApp(LakshyaApp(controller: controller));
}
