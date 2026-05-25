import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../model/lakshya_graph.dart';
import '../service/cloud_sync_config.dart';
import '../service/graph_document_migrator.dart';
import '../service/schema_validator.dart';
import 'graph_repository.dart';

const _cloudKitScriptUrl = 'https://cdn.apple-CloudKit.com/ck/2/CloudKit.js';
const _recordType = 'LakshyaDocument';
const _recordName = 'primary-graph';
const _graphFieldName = 'graphJson';

class ICloudGraphRepository implements GraphRepository {
  ICloudGraphRepository._({
    required this.validator,
    required this.migrator,
    required this._database,
  });

  final SchemaValidator validator;
  final GraphDocumentMigrator migrator;
  final JSObject _database;

  @override
  Future<LakshyaGraph?> load() async {
    final response = await _database
        .callMethod<JSPromise<JSAny?>>('fetchRecords'.toJS, _recordName.toJS)
        .toDart;
    final result = response as JSObject;
    final hasErrors = _boolProperty(result, 'hasErrors');
    if (hasErrors) {
      final errors = _arrayProperty(result, 'errors');
      final firstMessage = errors.isEmpty ? null : _errorMessage(errors.first);
      if (firstMessage != null && firstMessage.contains('Unknown Item')) {
        return null;
      }
      throw StateError(firstMessage ?? 'CloudKit could not fetch the graph.');
    }

    final records = _arrayProperty(result, 'records');
    if (records.isEmpty) return null;
    final raw = _graphJsonFromRecord(records.first);
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final migrated = migrator.migrate(decoded);
    validator.validateOrThrow(migrated);
    return LakshyaGraph.fromJson(migrated);
  }

  @override
  Future<void> save(LakshyaGraph graph) async {
    final response = await _database
        .callMethod<JSPromise<JSAny?>>(
          'saveRecords'.toJS,
          _buildRecord(json.encode(graph.toJson())),
        )
        .toDart;
    final result = response as JSObject;
    if (_boolProperty(result, 'hasErrors')) {
      final errors = _arrayProperty(result, 'errors');
      final firstMessage = errors.isEmpty ? null : _errorMessage(errors.first);
      throw StateError(firstMessage ?? 'CloudKit could not save the graph.');
    }
  }

  JSObject _buildRecord(String graphJson) {
    final graphField = JSObject()
      ..setProperty('value'.toJS, graphJson.toJS);
    final fields = JSObject()..setProperty(_graphFieldName.toJS, graphField);
    return JSObject()
      ..setProperty('recordType'.toJS, _recordType.toJS)
      ..setProperty('recordName'.toJS, _recordName.toJS)
      ..setProperty('fields'.toJS, fields);
  }
}

Future<ICloudGraphRepository> connectICloudGraphRepository(
  CloudSyncConfig config, {
  SchemaValidator? validator,
  GraphDocumentMigrator migrator = const GraphDocumentMigrator(),
}) async {
  if (!config.isWeb) {
    throw UnsupportedError('CloudKit sync is only available on the web build.');
  }
  if (!config.hasICloudConfig) {
    throw StateError(
      'Missing LAKSHYA_ICLOUD_CONTAINER_ID or LAKSHYA_ICLOUD_API_TOKEN.',
    );
  }

  await _ensureCloudKitLoaded();
  final cloudKit = _cloudKitGlobal();
  _configureCloudKit(cloudKit, config);
  _ensureAuthButtonsInDom();

  final container = cloudKit
      .callMethod<JSObject>('getDefaultContainer'.toJS);
  final initialIdentity =
      await container.callMethod<JSPromise<JSAny?>>('setUpAuth'.toJS).toDart;
  if (initialIdentity == null || initialIdentity.isUndefinedOrNull) {
    await container.callMethod<JSPromise<JSAny?>>('whenUserSignsIn'.toJS).toDart;
  }

  final database =
      container.getProperty<JSObject>('privateCloudDatabase'.toJS);
  return ICloudGraphRepository._(
    validator: validator ?? await _loadSchemaValidator(),
    migrator: migrator,
    _database: database,
  );
}

Future<SchemaValidator> _loadSchemaValidator() async {
  final schemaText =
      await web.window.fetch('schema/lakshya.schema.json'.toJS).toDart
          as web.Response;
  final body = (await schemaText.text().toDart).toDart;
  return SchemaValidator.fromString(body);
}

Future<void> _ensureCloudKitLoaded() async {
  if (web.window.has('CloudKit')) return;
  final completer = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = _cloudKitScriptUrl
    ..async = true;
  script.onload = ((web.Event _) => completer.complete()).toJS;
  script.onerror = ((web.Event _) {
    completer.completeError(StateError('Could not load CloudKit JS.'));
  }).toJS;
  web.document.head?.append(script);
  await completer.future;
}

JSObject _cloudKitGlobal() {
  final global = web.window.getProperty<JSAny?>('CloudKit'.toJS);
  if (global == null || global.isUndefinedOrNull || !global.isA<JSObject>()) {
    throw StateError('CloudKit JS is not available.');
  }
  return global as JSObject;
}

void _configureCloudKit(JSObject cloudKit, CloudSyncConfig config) {
  final signInButton = JSObject()
    ..setProperty('id'.toJS, 'apple-sign-in-button'.toJS)
    ..setProperty('theme'.toJS, 'black'.toJS);
  final signOutButton = JSObject()
    ..setProperty('id'.toJS, 'apple-sign-out-button'.toJS)
    ..setProperty('theme'.toJS, 'black'.toJS);
  final apiTokenAuth = JSObject()
    ..setProperty('apiToken'.toJS, config.iCloudApiToken!.toJS)
    ..setProperty('persist'.toJS, true.toJS)
    ..setProperty('signInButton'.toJS, signInButton)
    ..setProperty('signOutButton'.toJS, signOutButton);
  final container = JSObject()
    ..setProperty('containerIdentifier'.toJS, config.iCloudContainerId!.toJS)
    ..setProperty('environment'.toJS, config.iCloudEnvironment.toJS)
    ..setProperty('apiTokenAuth'.toJS, apiTokenAuth);
  final configuration = JSObject()
    ..setProperty('containers'.toJS, [container].toJS);
  cloudKit.callMethod<JSObject>('configure'.toJS, configuration);
}

void _ensureAuthButtonsInDom() {
  _ensureAuthHost(
    id: 'apple-sign-in-button',
    bottomPx: 88,
    label: 'Apple sign-in',
  );
  _ensureAuthHost(
    id: 'apple-sign-out-button',
    bottomPx: 40,
    label: 'Apple sign-out',
  );
}

void _ensureAuthHost({
  required String id,
  required int bottomPx,
  required String label,
}) {
  if (web.document.getElementById(id) != null) return;
  final host = web.HTMLDivElement()
    ..id = id
    ..setAttribute('aria-label', label)
    ..style.position = 'fixed'
    ..style.right = '16px'
    ..style.bottom = '${bottomPx}px'
    ..style.zIndex = '2147483647';
  web.document.body?.append(host);
}

bool _boolProperty(JSObject object, String property) {
  final value = object.getProperty<JSAny?>(property.toJS);
  return value != null && value.toDartBool == true;
}

List<JSObject> _arrayProperty(JSObject object, String property) {
  final value = object.getProperty<JSAny?>(property.toJS);
  if (value == null || value.isUndefinedOrNull || !value.isA<JSArray>()) {
    return const [];
  }
  final list = value as JSArray<JSAny?>;
  return [
    for (var i = 0; i < list.length; i++)
      if (list[i] != null && list[i]!.isA<JSObject>()) list[i]! as JSObject,
  ];
}

String? _graphJsonFromRecord(JSObject record) {
  final fields = record.getProperty<JSAny?>('fields'.toJS);
  if (fields == null || fields.isUndefinedOrNull || !fields.isA<JSObject>()) {
    return null;
  }
  final field = (fields as JSObject).getProperty<JSAny?>(_graphFieldName.toJS);
  if (field == null || field.isUndefinedOrNull || !field.isA<JSObject>()) {
    return null;
  }
  final value = (field as JSObject).getProperty<JSAny?>('value'.toJS);
  return value?.dartify() as String?;
}

String? _errorMessage(JSObject error) {
  final serverErrorCode = error.getProperty<JSAny?>('serverErrorCode'.toJS);
  if (serverErrorCode != null) {
    final code = serverErrorCode.dartify();
    if ('$code' == 'UNKNOWN_ITEM') return 'Unknown Item';
  }
  final reason = error.getProperty<JSAny?>('reason'.toJS)?.dartify();
  final message = error.getProperty<JSAny?>('message'.toJS)?.dartify();
  return (reason ?? message)?.toString();
}
