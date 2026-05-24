import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../model/lakshya_graph.dart';
import '../service/schema_validator.dart';
import 'graph_repository.dart';

/// Browser-File-System-Access-API-backed file sync. The on-disk file is the
/// durable record; only the handle (the browser's permission token) lives in
/// IndexedDB.
///
/// If the user clears browsing data, the handle is lost but the file on disk
/// remains untouched — they can re-pick the same file via Settings and
/// continue where they left off.
class WebGraphFileSync {
  const WebGraphFileSync();

  static const String _idbDatabaseName = 'lakshya-handles';
  static const String _idbStoreName = 'handles';
  static const String _idbKey = 'graph';
  static const int _idbVersion = 1;

  bool get isSupported {
    return web.window.has('showSaveFilePicker');
  }

  Future<String?> currentFileName() async {
    final handle = await _loadStoredHandle();
    if (handle == null) return null;
    final name = handle.getProperty<JSString?>('name'.toJS);
    return name?.toDart;
  }

  Future<void> forget() async {
    await _runIdbTx(readwrite: true, (store) async {
      store.delete(_idbKey.toJS);
    });
  }

  /// Tries to rebuild the file-backed repository from the previously-saved
  /// handle. Returns null when there's no saved handle or the user denies
  /// re-granting permission.
  Future<GraphRepository?> tryRestoreRepository({
    required SchemaValidator validator,
  }) async {
    if (!isSupported) return null;
    final handle = await _loadStoredHandle();
    if (handle == null) return null;
    final state = await _ensurePermission(handle, prompt: false);
    if (state != 'granted') return null;
    return _FileSystemAccessGraphRepository(
      handle: handle,
      validator: validator,
    );
  }

  /// Opens a "save file" dialog so the user picks a new file (or replaces an
  /// existing one) to use as the backing store. The handle is persisted in
  /// IndexedDB for the next session. Returns null when the user cancels.
  Future<GraphRepository?> pickFileAsBackingStore({
    required SchemaValidator validator,
    required String suggestedName,
  }) async {
    if (!isSupported) return null;
    final handle = await _showSaveFilePicker(suggestedName);
    if (handle == null) return null;
    final state = await _ensurePermission(handle, prompt: true);
    if (state != 'granted') return null;
    await _storeHandle(handle);
    return _FileSystemAccessGraphRepository(
      handle: handle,
      validator: validator,
    );
  }

  /// Opens an "open file" dialog so the user picks an EXISTING file to load
  /// from. The file's current contents replace the in-memory graph (caller's
  /// responsibility — coordinator handles it), and the handle is persisted
  /// so subsequent saves go to that same file.
  Future<GraphRepository?> openFileAsBackingStore({
    required SchemaValidator validator,
  }) async {
    if (!isSupported) return null;
    final handle = await _showOpenFilePicker();
    if (handle == null) return null;
    final state = await _ensurePermission(handle, prompt: true);
    if (state != 'granted') return null;
    await _storeHandle(handle);
    return _FileSystemAccessGraphRepository(
      handle: handle,
      validator: validator,
    );
  }

  // --- JS bridge -----------------------------------------------------------

  Future<JSObject?> _showSaveFilePicker(String suggestedName) async {
    final options = _buildPickerOptions(suggestedName: suggestedName);
    try {
      final result = await web.window
          .callMethod<JSPromise<JSAny?>>('showSaveFilePicker'.toJS, options)
          .toDart;
      return result as JSObject?;
    } catch (_) {
      // AbortError on cancel, or various other errors. We treat all as
      // "user backed out".
      return null;
    }
  }

  Future<JSObject?> _showOpenFilePicker() async {
    final options = _buildPickerOptions();
    options.setProperty('multiple'.toJS, false.toJS);
    try {
      final result = await web.window
          .callMethod<JSPromise<JSAny?>>('showOpenFilePicker'.toJS, options)
          .toDart;
      // showOpenFilePicker resolves to an array of handles (even with
      // multiple:false); we want the first one.
      final list = result as JSArray<JSAny?>?;
      if (list == null || list.length == 0) return null;
      return list[0] as JSObject?;
    } catch (_) {
      return null;
    }
  }

  JSObject _buildPickerOptions({String? suggestedName}) {
    final accept = JSObject();
    accept.setProperty('application/json'.toJS, ['.json'.toJS].toJS);
    final type = JSObject();
    type.setProperty('description'.toJS, 'JSON'.toJS);
    type.setProperty('accept'.toJS, accept);
    final options = JSObject();
    if (suggestedName != null) {
      options.setProperty('suggestedName'.toJS, suggestedName.toJS);
    }
    options.setProperty('types'.toJS, [type].toJS);
    return options;
  }

  Future<String> _ensurePermission(JSObject handle,
      {required bool prompt}) async {
    final descriptor = JSObject()..setProperty('mode'.toJS, 'readwrite'.toJS);
    final query = await handle
        .callMethod<JSPromise<JSAny?>>('queryPermission'.toJS, descriptor)
        .toDart;
    final current = (query as JSString?)?.toDart;
    if (current == 'granted') return 'granted';
    if (!prompt) return current ?? 'denied';
    final request = await handle
        .callMethod<JSPromise<JSAny?>>('requestPermission'.toJS, descriptor)
        .toDart;
    return (request as JSString?)?.toDart ?? 'denied';
  }

  // --- IndexedDB persistence ----------------------------------------------

  Future<void> _storeHandle(JSObject handle) async {
    await _runIdbTx(readwrite: true, (store) async {
      store.put(handle, _idbKey.toJS);
    });
  }

  Future<JSObject?> _loadStoredHandle() async {
    JSObject? result;
    await _runIdbTx(readwrite: false, (store) async {
      final req = store.get(_idbKey.toJS);
      await _waitForRequest(req);
      final value = req.result;
      if (value != null && value.isA<JSObject>()) {
        result = value as JSObject;
      }
    });
    return result;
  }

  Future<void> _runIdbTx(
    Future<void> Function(web.IDBObjectStore store) body, {
    required bool readwrite,
  }) async {
    final db = await _openIdb();
    final tx = db.transaction(
      _idbStoreName.toJS,
      readwrite ? 'readwrite' : 'readonly',
    );
    final store = tx.objectStore(_idbStoreName);
    await body(store);
    await _waitForTransaction(tx);
    db.close();
  }

  Future<web.IDBDatabase> _openIdb() async {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB
        .open(_idbDatabaseName, _idbVersion);
    request.onupgradeneeded = ((web.IDBVersionChangeEvent _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_idbStoreName)) {
        db.createObjectStore(_idbStoreName);
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(
        StateError('Could not open IndexedDB: ${request.error?.message}'),
      );
    }).toJS;
    return completer.future;
  }

  Future<void> _waitForRequest(web.IDBRequest req) {
    final completer = Completer<void>();
    req.onsuccess = ((web.Event _) => completer.complete()).toJS;
    req.onerror = ((web.Event _) {
      completer.completeError(
        StateError('IndexedDB request failed: ${req.error?.message}'),
      );
    }).toJS;
    return completer.future;
  }

  Future<void> _waitForTransaction(web.IDBTransaction tx) {
    final completer = Completer<void>();
    tx.oncomplete = ((web.Event _) => completer.complete()).toJS;
    tx.onerror = ((web.Event _) {
      completer.completeError(
        StateError('IndexedDB transaction failed: ${tx.error?.message}'),
      );
    }).toJS;
    tx.onabort = ((web.Event _) {
      completer.completeError(StateError('IndexedDB transaction aborted'));
    }).toJS;
    return completer.future;
  }
}

class _FileSystemAccessGraphRepository implements GraphRepository {
  _FileSystemAccessGraphRepository({
    required this.handle,
    required this.validator,
  });

  static const _encoder = JsonEncoder.withIndent('  ');

  final JSObject handle;
  final SchemaValidator validator;

  @override
  Future<LakshyaGraph?> load() async {
    final fileObj = await handle
        .callMethod<JSPromise<JSAny?>>('getFile'.toJS)
        .toDart;
    final file = fileObj as web.File;
    final textPromise = file.text();
    final raw = (await textPromise.toDart).toDart;
    if (raw.trim().isEmpty) return null;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    validator.validateOrThrow(decoded);
    return LakshyaGraph.fromJson(decoded);
  }

  @override
  Future<void> save(LakshyaGraph graph) async {
    final writable = await handle
        .callMethod<JSPromise<JSAny?>>('createWritable'.toJS)
        .toDart;
    final stream = writable as JSObject;
    final body = _encoder.convert(graph.toJson());
    await stream
        .callMethod<JSPromise<JSAny?>>('write'.toJS, body.toJS)
        .toDart;
    await stream.callMethod<JSPromise<JSAny?>>('close'.toJS).toDart;
  }
}
