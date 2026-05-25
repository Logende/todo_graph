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
      iCloudContainerId: _env('LAKSHYA_ICLOUD_CONTAINER_ID'),
      iCloudApiToken: _env('LAKSHYA_ICLOUD_API_TOKEN'),
      iCloudEnvironment:
          _env('LAKSHYA_ICLOUD_ENVIRONMENT') ?? 'development',
    );
  }

  final bool isWeb;
  final String? iCloudContainerId;
  final String? iCloudApiToken;
  final String iCloudEnvironment;

  bool get hasICloudConfig =>
      _hasValue(iCloudContainerId) && _hasValue(iCloudApiToken);

  static String? _env(String name) {
    const missing = '';
    final value = String.fromEnvironment(name, defaultValue: missing).trim();
    return value.isEmpty ? null : value;
  }

  static bool _hasValue(String? value) => value != null && value.isNotEmpty;
}
