import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/graph_controller.dart';
import 'app/lakshya_app.dart';
import 'model/lakshya_graph.dart';
import 'repository/shared_preferences_graph_repository.dart';
import 'service/asset_seed_loader.dart';
import 'service/id_generator.dart';
import 'service/schema_validator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final validator = await _loadSchemaValidator();
  final preferences = await SharedPreferences.getInstance();
  final repository = SharedPreferencesGraphRepository(
    preferences: preferences,
    validator: validator,
  );
  final initialGraph = await _loadOrBootstrapGraph(
    repository: repository,
    validator: validator,
  );
  final controller = GraphController(
    initial: initialGraph,
    save: repository.save,
    idGenerator: UuidV4IdGenerator(),
    clock: DateTime.now,
  );

  runApp(LakshyaApp(controller: controller));
}

Future<SchemaValidator> _loadSchemaValidator() async {
  final schemaText =
      await rootBundle.loadString('schema/lakshya.schema.json');
  return SchemaValidator.fromString(schemaText);
}

Future<LakshyaGraph> _loadOrBootstrapGraph({
  required SharedPreferencesGraphRepository repository,
  required SchemaValidator validator,
}) async {
  try {
    final loaded = await repository.load();
    if (loaded != null) return loaded;
  } on SchemaValidationException {
    // Pre-release: no migration path. Fall through to a fresh seed.
  }
  final seed = await _loadSeedFromAsset(validator: validator);
  await repository.save(seed);
  return seed;
}

Future<LakshyaGraph> _loadSeedFromAsset({
  required SchemaValidator validator,
}) async {
  final seedJson = await rootBundle.loadString('assets/example_seed.json');
  return AssetSeedLoader(validator: validator).parse(seedJson);
}
