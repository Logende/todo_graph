import 'cloud_sync_config.dart';

enum CloudSyncProviderId { iCloud }

enum CloudSyncProviderStatus {
  readyForImplementation,
  missingConfiguration,
  unsupportedPlatform,
}

class CloudSyncProviderDescriptor {
  const CloudSyncProviderDescriptor({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusMessage,
    required this.setupHint,
  });

  final CloudSyncProviderId id;
  final String title;
  final String subtitle;
  final CloudSyncProviderStatus status;
  final String statusMessage;
  final String setupHint;

  bool get canStartIntegration =>
      status == CloudSyncProviderStatus.readyForImplementation;
}

abstract class CloudSyncProvider {
  const CloudSyncProvider();

  CloudSyncProviderDescriptor describe(CloudSyncConfig config);
}

class ICloudCloudSyncProvider extends CloudSyncProvider {
  const ICloudCloudSyncProvider();

  @override
  CloudSyncProviderDescriptor describe(CloudSyncConfig config) {
    if (!config.isWeb) {
      return const CloudSyncProviderDescriptor(
        id: CloudSyncProviderId.iCloud,
        title: 'Apple iCloud',
        subtitle: 'CloudKit-backed app storage for Apple users on the web.',
        status: CloudSyncProviderStatus.unsupportedPlatform,
        statusMessage: 'Only the web build can use CloudKit JS.',
        setupHint:
            'Provide LAKSHYA_ICLOUD_CONTAINER_ID and LAKSHYA_ICLOUD_API_TOKEN '
            'when building the web app.',
      );
    }
    if (!config.hasICloudConfig) {
      return const CloudSyncProviderDescriptor(
        id: CloudSyncProviderId.iCloud,
        title: 'Apple iCloud',
        subtitle: 'Uses CloudKit rather than browsing arbitrary iCloud Drive files.',
        status: CloudSyncProviderStatus.missingConfiguration,
        statusMessage: 'Missing CloudKit container ID or API token.',
        setupHint:
            'Create a CloudKit container, enable web services, then set '
            'LAKSHYA_ICLOUD_CONTAINER_ID and LAKSHYA_ICLOUD_API_TOKEN.',
      );
    }
    return const CloudSyncProviderDescriptor(
      id: CloudSyncProviderId.iCloud,
      title: 'Apple iCloud',
      subtitle: 'Uses CloudKit rather than browsing arbitrary iCloud Drive files.',
      status: CloudSyncProviderStatus.readyForImplementation,
      statusMessage: 'CloudKit credentials are configured.',
      setupHint:
          'Next implementation step: sign in with CloudKit JS and store the '
          'graph in the user’s private database.',
    );
  }
}
