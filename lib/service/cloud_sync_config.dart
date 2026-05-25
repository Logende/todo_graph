import 'package:flutter/foundation.dart';

class CloudSyncConfig {
  const CloudSyncConfig({
    required this.isWeb,
    this.iCloudContainerId,
    this.iCloudApiToken,
    this.iCloudEnvironment = 'development',
  });

  factory CloudSyncConfig.fromEnvironment() {
    return CloudSyncConfig(
      isWeb: kIsWeb,
      iCloudContainerId: _iCloudContainerId,
      iCloudApiToken: _iCloudApiToken,
      iCloudEnvironment: _iCloudEnvironment,
    );
  }

  final bool isWeb;
  final String? iCloudContainerId;
  final String? iCloudApiToken;
  final String iCloudEnvironment;

  bool get hasICloudConfig =>
      _hasValue(iCloudContainerId) && _hasValue(iCloudApiToken);

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

final String? _iCloudContainerId =
    _rawICloudContainerId.trim().isEmpty ? null : _rawICloudContainerId.trim();
final String? _iCloudApiToken =
    _rawICloudApiToken.trim().isEmpty ? null : _rawICloudApiToken.trim();
final String _iCloudEnvironment =
    _rawICloudEnvironment.trim().isEmpty ? 'development' : _rawICloudEnvironment.trim();
