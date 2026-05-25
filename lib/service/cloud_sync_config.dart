import 'package:flutter/foundation.dart';

class CloudSyncConfig {
  const CloudSyncConfig({
    required this.isWeb,
    this.iCloudContainerId,
    this.iCloudApiToken,
    this.iCloudEnvironment = 'development',
    this.dropboxAppKey,
    this.oneDriveAppId,
    this.oneDriveRedirectUri,
  });

  factory CloudSyncConfig.fromEnvironment() {
    return CloudSyncConfig(
      isWeb: kIsWeb,
      iCloudContainerId: _env('LAKSHYA_ICLOUD_CONTAINER_ID'),
      iCloudApiToken: _env('LAKSHYA_ICLOUD_API_TOKEN'),
      iCloudEnvironment:
          _env('LAKSHYA_ICLOUD_ENVIRONMENT') ?? 'development',
      dropboxAppKey: _env('LAKSHYA_DROPBOX_APP_KEY'),
      oneDriveAppId: _env('LAKSHYA_ONEDRIVE_APP_ID'),
      oneDriveRedirectUri: _env('LAKSHYA_ONEDRIVE_REDIRECT_URI'),
    );
  }

  final bool isWeb;
  final String? iCloudContainerId;
  final String? iCloudApiToken;
  final String iCloudEnvironment;
  final String? dropboxAppKey;
  final String? oneDriveAppId;
  final String? oneDriveRedirectUri;

  bool get hasICloudConfig =>
      _hasValue(iCloudContainerId) && _hasValue(iCloudApiToken);
  bool get hasDropboxConfig => _hasValue(dropboxAppKey);
  bool get hasOneDriveConfig =>
      _hasValue(oneDriveAppId) && _hasValue(oneDriveRedirectUri);

  static String? _env(String name) {
    const missing = '';
    final value = String.fromEnvironment(name, defaultValue: missing).trim();
    return value.isEmpty ? null : value;
  }

  static bool _hasValue(String? value) => value != null && value.isNotEmpty;
}
