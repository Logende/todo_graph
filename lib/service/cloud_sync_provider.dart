import 'cloud_sync_config.dart';

enum CloudSyncProviderId { iCloud, dropbox, oneDrive }

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

class DropboxCloudSyncProvider extends CloudSyncProvider {
  const DropboxCloudSyncProvider();

  @override
  CloudSyncProviderDescriptor describe(CloudSyncConfig config) {
    if (!config.isWeb) {
      return const CloudSyncProviderDescriptor(
        id: CloudSyncProviderId.dropbox,
        title: 'Dropbox',
        subtitle: 'Dropbox OAuth + file API integration.',
        status: CloudSyncProviderStatus.unsupportedPlatform,
        statusMessage: 'This provider is planned for the web build.',
        setupHint: 'Provide LAKSHYA_DROPBOX_APP_KEY in the web build.',
      );
    }
    if (!config.hasDropboxConfig) {
      return const CloudSyncProviderDescriptor(
        id: CloudSyncProviderId.dropbox,
        title: 'Dropbox',
        subtitle: 'Dropbox OAuth + file API integration.',
        status: CloudSyncProviderStatus.missingConfiguration,
        statusMessage: 'Missing Dropbox app key.',
        setupHint:
            'Create a Dropbox app and set LAKSHYA_DROPBOX_APP_KEY for the '
            'web build.',
      );
    }
    return const CloudSyncProviderDescriptor(
      id: CloudSyncProviderId.dropbox,
      title: 'Dropbox',
      subtitle: 'Dropbox OAuth + file API integration.',
      status: CloudSyncProviderStatus.readyForImplementation,
      statusMessage: 'Dropbox app key is configured.',
      setupHint:
          'Next implementation step: browser OAuth and upload/download of a '
          'single graph document via the Dropbox API.',
    );
  }
}

class OneDriveCloudSyncProvider extends CloudSyncProvider {
  const OneDriveCloudSyncProvider();

  @override
  CloudSyncProviderDescriptor describe(CloudSyncConfig config) {
    if (!config.isWeb) {
      return const CloudSyncProviderDescriptor(
        id: CloudSyncProviderId.oneDrive,
        title: 'Microsoft OneDrive',
        subtitle: 'OneDrive picker + Microsoft Graph integration.',
        status: CloudSyncProviderStatus.unsupportedPlatform,
        statusMessage: 'This provider is planned for the web build.',
        setupHint:
            'Provide LAKSHYA_ONEDRIVE_APP_ID and '
            'LAKSHYA_ONEDRIVE_REDIRECT_URI in the web build.',
      );
    }
    if (!config.hasOneDriveConfig) {
      return const CloudSyncProviderDescriptor(
        id: CloudSyncProviderId.oneDrive,
        title: 'Microsoft OneDrive',
        subtitle: 'OneDrive picker + Microsoft Graph integration.',
        status: CloudSyncProviderStatus.missingConfiguration,
        statusMessage: 'Missing OneDrive app ID or redirect URI.',
        setupHint:
            'Register an Azure app and set LAKSHYA_ONEDRIVE_APP_ID plus '
            'LAKSHYA_ONEDRIVE_REDIRECT_URI.',
      );
    }
    return const CloudSyncProviderDescriptor(
      id: CloudSyncProviderId.oneDrive,
      title: 'Microsoft OneDrive',
      subtitle: 'OneDrive picker + Microsoft Graph integration.',
      status: CloudSyncProviderStatus.readyForImplementation,
      statusMessage: 'OneDrive app registration is configured.',
      setupHint:
          'Next implementation step: authenticate with Microsoft and bind a '
          'single graph file for repeated load/save.',
    );
  }
}
