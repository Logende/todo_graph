import 'package:flutter/foundation.dart';

class CloudSyncConfig {
  const CloudSyncConfig({
    required this.isWeb,
    this.iCloudContainerId,
    this.iCloudApiToken,
    this.iCloudEnvironment = 'development',
    this.oneDriveAppId,
    this.oneDriveRedirectUri,
  });

  factory CloudSyncConfig.fromEnvironment() {
    return CloudSyncConfig(
      isWeb: kIsWeb,
      iCloudContainerId: _iCloudContainerId,
      iCloudApiToken: _iCloudApiToken,
      iCloudEnvironment: _iCloudEnvironment,
      oneDriveAppId: _oneDriveAppId,
      oneDriveRedirectUri: _oneDriveRedirectUri,
    );
  }

  final bool isWeb;
  final String? iCloudContainerId;
  final String? iCloudApiToken;
  final String iCloudEnvironment;
  final String? oneDriveAppId;
  final String? oneDriveRedirectUri;

  bool get hasICloudConfig =>
      _hasValue(iCloudContainerId) && _hasValue(iCloudApiToken);
  bool get hasOneDriveConfig =>
      _hasValue(oneDriveAppId) && _hasValue(oneDriveRedirectUri);

  static bool _hasValue(String? value) => value != null && value.isNotEmpty;
}

const _rawICloudContainerId = String.fromEnvironment(
  'LAKSHYA_ICLOUD_CONTAINER_ID',
  defaultValue: '',
);
const _rawICloudApiToken = String.fromEnvironment(
  'LAKSHYA_ICLOUD_API_TOKEN',
  defaultValue: '',
);
const _rawICloudEnvironment = String.fromEnvironment(
  'LAKSHYA_ICLOUD_ENVIRONMENT',
  defaultValue: 'development',
);
const _rawOneDriveAppId = String.fromEnvironment(
  'LAKSHYA_ONEDRIVE_APP_ID',
  defaultValue: '',
);
const _rawOneDriveRedirectUri = String.fromEnvironment(
  'LAKSHYA_ONEDRIVE_REDIRECT_URI',
  defaultValue: '',
);

final String? _iCloudContainerId =
    _rawICloudContainerId.trim().isEmpty ? null : _rawICloudContainerId.trim();
final String? _iCloudApiToken =
    _rawICloudApiToken.trim().isEmpty ? null : _rawICloudApiToken.trim();
final String _iCloudEnvironment =
    _rawICloudEnvironment.trim().isEmpty ? 'development' : _rawICloudEnvironment.trim();
final String? _oneDriveAppId =
    _rawOneDriveAppId.trim().isEmpty ? null : _rawOneDriveAppId.trim();
final String? _oneDriveRedirectUri = _rawOneDriveRedirectUri.trim().isEmpty
    ? null
    : _rawOneDriveRedirectUri.trim();
