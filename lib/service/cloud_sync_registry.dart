import 'cloud_sync_config.dart';
import 'cloud_sync_provider.dart';

class CloudSyncRegistry {
  CloudSyncRegistry({
    required this.config,
    List<CloudSyncProvider>? providers,
  }) : providers = providers ?? const [OneDriveCloudSyncProvider()];

  factory CloudSyncRegistry.fromEnvironment() {
    return CloudSyncRegistry(config: CloudSyncConfig.fromEnvironment());
  }

  final CloudSyncConfig config;
  final List<CloudSyncProvider> providers;

  List<CloudSyncProviderDescriptor> describeAll() {
    return providers.map((provider) => provider.describe(config)).toList();
  }
}
