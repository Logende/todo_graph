import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../model/lakshya_graph.dart';
import '../service/cloud_sync_config.dart';
import '../service/graph_document_migrator.dart';
import '../service/schema_validator.dart';
import 'graph_repository.dart';

class OneDriveGraphRepository implements GraphRepository {
  OneDriveGraphRepository._({
    required this.validator,
    required this.migrator,
    required this._auth,
  });

  final SchemaValidator validator;
  final GraphDocumentMigrator migrator;
  final _OneDriveAuthSession _auth;

  @override
  Future<LakshyaGraph?> load() async {
    final token = await _auth.ensureAccessToken();
    final appRootId = await _ensureAppRootId(token);
    final response = await _graphFetch(
      '/me/drive/items/$appRootId:/lakshya_graph.json:/content',
      token: token,
      method: 'GET',
    );
    if (response.status == 404) return null;
    if (!response.ok) {
      throw StateError(
        'OneDrive load failed (${response.status}): ${await _responseText(response)}',
      );
    }
    final raw = await _responseText(response);
    if (raw.trim().isEmpty) return null;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final migrated = migrator.migrate(decoded);
    validator.validateOrThrow(migrated);
    return LakshyaGraph.fromJson(migrated);
  }

  @override
  Future<void> save(LakshyaGraph graph) async {
    final token = await _auth.ensureAccessToken();
    final appRootId = await _ensureAppRootId(token);
    final response = await _graphFetch(
      '/me/drive/items/$appRootId:/lakshya_graph.json:/content',
      token: token,
      method: 'PUT',
      body: json.encode(graph.toJson()),
      headers: const {'Content-Type': 'application/json'},
    );
    if (!response.ok) {
      throw StateError(
        'OneDrive save failed (${response.status}): ${await _responseText(response)}',
      );
    }
  }

  Future<String> _ensureAppRootId(String token) async {
    final response = await _graphFetch(
      '/me/drive/special/approot',
      token: token,
      method: 'GET',
    );
    if (!response.ok) {
      throw StateError(
        'Could not access the OneDrive app folder (${response.status}): '
        '${await _responseText(response)}',
      );
    }
    final decoded =
        json.decode(await _responseText(response)) as Map<String, dynamic>;
    final id = decoded['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('The OneDrive app folder response did not include an id.');
    }
    return id;
  }
}

Future<OneDriveGraphRepository> connectOneDriveGraphRepository(
  CloudSyncConfig config, {
  SchemaValidator? validator,
  GraphDocumentMigrator migrator = const GraphDocumentMigrator(),
}) async {
  if (!config.isWeb) {
    throw UnsupportedError('OneDrive sync is only available on the web build.');
  }
  if (!config.hasOneDriveConfig) {
    throw StateError(
      'Missing LAKSHYA_ONEDRIVE_APP_ID or LAKSHYA_ONEDRIVE_REDIRECT_URI.',
    );
  }
  final auth = _OneDriveAuthSession(config);
  await auth.ensureAccessToken();
  return OneDriveGraphRepository._(
    validator: validator ?? await _loadSchemaValidator(),
    migrator: migrator,
    auth: auth,
  );
}

const _graphBase = 'https://graph.microsoft.com/v1.0';
const _authorizeBase =
    'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
const _tokenBase =
    'https://login.microsoftonline.com/common/oauth2/v2.0/token';
const _tokenStorageKey = 'lakshya.onedrive.oauth';

class _OneDriveAuthSession {
  _OneDriveAuthSession(this.config);

  final CloudSyncConfig config;

  Future<String> ensureAccessToken() async {
    final current = _StoredToken.tryLoad();
    if (current != null && !current.isExpiredSoon) return current.accessToken;
    if (current?.refreshToken case final refreshToken?) {
      final refreshed = await _refresh(refreshToken);
      refreshed.store();
      return refreshed.accessToken;
    }
    final interactive = await _interactiveSignIn();
    interactive.store();
    return interactive.accessToken;
  }

  Future<_StoredToken> _interactiveSignIn() async {
    final verifier = _randomUrlSafe(64);
    final challenge = await _pkceChallenge(verifier);
    final state = _randomUrlSafe(32);
    final completer = Completer<String>();

    late web.EventListener listener;
    listener = ((web.Event event) {
      if (!(event as JSAny).isA<web.MessageEvent>()) return;
      final message = event as web.MessageEvent;
      if (message.origin != web.window.location.origin) return;
      final data = message.data;
      if (data == null || !data.isA<JSObject>()) return;
      final object = data as JSObject;
      final type = object.getProperty<JSAny?>('type'.toJS)?.dartify();
      if (type != 'lakshya-onedrive-auth') return;
      final returnedState =
          object.getProperty<JSAny?>('state'.toJS)?.dartify() as String?;
      if (returnedState != state) return;
      web.window.removeEventListener('message', listener);

      final error =
          object.getProperty<JSAny?>('error'.toJS)?.dartify() as String?;
      final description = object
          .getProperty<JSAny?>('error_description'.toJS)
          ?.dartify() as String?;
      if (error != null) {
        completer.completeError(
          StateError(description == null ? error : '$error: $description'),
        );
        return;
      }
      final code =
          object.getProperty<JSAny?>('code'.toJS)?.dartify() as String?;
      if (code == null || code.isEmpty) {
        completer.completeError(
          StateError('OneDrive sign-in returned no authorization code.'),
        );
        return;
      }
      completer.complete(code);
    }).toJS;
    web.window.addEventListener('message', listener);

    final authorizeUri = Uri.parse(_authorizeBase).replace(queryParameters: {
      'client_id': config.oneDriveAppId!,
      'response_type': 'code',
      'redirect_uri': config.oneDriveRedirectUri!,
      'response_mode': 'query',
      'scope': 'openid profile offline_access Files.ReadWrite.AppFolder',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
    });
    final popup = web.window.open(
      authorizeUri.toString(),
      'lakshya-onedrive-auth',
      'popup,width=520,height=720',
    );
    if (popup == null) {
      web.window.removeEventListener('message', listener);
      throw StateError(
        'The browser blocked the OneDrive sign-in popup. Allow popups and retry.',
      );
    }

    final code = await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        web.window.removeEventListener('message', listener);
        throw TimeoutException('Timed out waiting for OneDrive sign-in.');
      },
    );
    return _exchangeAuthorizationCode(code, verifier);
  }

  Future<_StoredToken> _exchangeAuthorizationCode(
    String code,
    String verifier,
  ) async {
    final response = await _postToken({
      'client_id': config.oneDriveAppId!,
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': config.oneDriveRedirectUri!,
      'code_verifier': verifier,
    });
    return _StoredToken.fromTokenResponse(response);
  }

  Future<_StoredToken> _refresh(String refreshToken) async {
    final response = await _postToken({
      'client_id': config.oneDriveAppId!,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'redirect_uri': config.oneDriveRedirectUri!,
      'scope': 'openid profile offline_access Files.ReadWrite.AppFolder',
    });
    return _StoredToken.fromTokenResponse(
      response,
      fallbackRefreshToken: refreshToken,
    );
  }

  Future<Map<String, dynamic>> _postToken(Map<String, String> form) async {
    final response = await web.window.fetch(
      _tokenBase.toJS,
      web.RequestInit(
        method: 'POST',
        body: Uri(queryParameters: form).query.toJS,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        }.jsify()! as web.HeadersInit,
      ),
    ).toDart;
    final httpResponse = response;
    final text = await _responseText(httpResponse);
    if (!httpResponse.ok) {
      throw StateError(
        'OneDrive token request failed (${httpResponse.status}): $text',
      );
    }
    return json.decode(text) as Map<String, dynamic>;
  }
}

class _StoredToken {
  const _StoredToken({
    required this.accessToken,
    required this.expiresAtUtcMs,
    this.refreshToken,
  });

  final String accessToken;
  final int expiresAtUtcMs;
  final String? refreshToken;

  bool get isExpiredSoon =>
      DateTime.now().millisecondsSinceEpoch + 60000 >= expiresAtUtcMs;

  void store() {
    web.window.localStorage.setItem(
      _tokenStorageKey,
      json.encode({
        'access_token': accessToken,
        'expires_at_utc_ms': expiresAtUtcMs,
        'refresh_token': refreshToken,
      }),
    );
  }

  static _StoredToken? tryLoad() {
    final raw = web.window.localStorage.getItem(_tokenStorageKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final accessToken = decoded['access_token'] as String?;
    final expiresAtUtcMs = decoded['expires_at_utc_ms'] as int?;
    if (accessToken == null || expiresAtUtcMs == null) return null;
    return _StoredToken(
      accessToken: accessToken,
      expiresAtUtcMs: expiresAtUtcMs,
      refreshToken: decoded['refresh_token'] as String?,
    );
  }

  factory _StoredToken.fromTokenResponse(
    Map<String, dynamic> json, {
    String? fallbackRefreshToken,
  }) {
    final accessToken = json['access_token'] as String?;
    final expiresIn = json['expires_in'];
    if (accessToken == null || expiresIn == null) {
      throw StateError('OneDrive token response was missing access token data.');
    }
    final seconds = expiresIn is int ? expiresIn : int.parse('$expiresIn');
    return _StoredToken(
      accessToken: accessToken,
      expiresAtUtcMs:
          DateTime.now().millisecondsSinceEpoch + (seconds * 1000),
      refreshToken: (json['refresh_token'] as String?) ?? fallbackRefreshToken,
    );
  }
}

Future<SchemaValidator> _loadSchemaValidator() async {
  final response =
      await web.window.fetch('schema/lakshya.schema.json'.toJS).toDart;
  return SchemaValidator.fromString(
    await _responseText(response),
  );
}

Future<web.Response> _graphFetch(
  String path, {
  required String token,
  required String method,
  String? body,
  Map<String, String>? headers,
}) async {
  final response = await web.window.fetch(
    '$_graphBase$path'.toJS,
    web.RequestInit(
      method: method,
      body: body?.toJS,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        ...?headers,
      }.jsify()! as web.HeadersInit,
    ),
  ).toDart;
  return response;
}

Future<String> _responseText(web.Response response) async {
  return (await response.text().toDart).toDart;
}

Future<String> _pkceChallenge(String verifier) async {
  final verifierBytes = Uint8List.fromList(utf8.encode(verifier));
  final algorithm = JSObject()..setProperty('name'.toJS, 'SHA-256'.toJS);
  final digest = await web.window.crypto.subtle
      .digest(algorithm as dynamic, verifierBytes.toJS)
      .toDart;
  final digestBuffer = digest.dartify() as ByteBuffer;
  return _base64UrlEncode(Uint8List.view(digestBuffer));
}

String _randomUrlSafe(int length) {
  final bytes = Uint8List(length);
  web.window.crypto.getRandomValues(bytes.toJS);
  return _base64UrlEncode(bytes).substring(0, length);
}

String _base64UrlEncode(Uint8List bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}
