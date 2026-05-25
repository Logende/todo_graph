import 'cloud_sync_config.dart';

enum CloudSyncProviderId { oneDrive }

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

class OneDriveCloudSyncProvider extends CloudSyncProvider {
  const OneDriveCloudSyncProvider();

  @override
  CloudSyncProviderDescriptor describe(CloudSyncConfig config) {
    if (!config.isWeb) {
      return const CloudSyncProviderDescriptor(
        id: CloudSyncProviderId.oneDrive,
        title: 'Microsoft OneDrive',
        subtitle: 'OneDrive-backed app storage for web and mobile Safari.',
        status: CloudSyncProviderStatus.unsupportedPlatform,
        statusMessage: 'Only the web build can use browser-based OneDrive auth.',
        setupHint:
            'Provide LAKSHYA_ONEDRIVE_APP_ID and '
            'LAKSHYA_ONEDRIVE_REDIRECT_URI when building the web app.',
      );
    }
    if (!config.hasOneDriveConfig) {
      return const CloudSyncProviderDescriptor(
        id: CloudSyncProviderId.oneDrive,
        title: 'Microsoft OneDrive',
        subtitle: 'Uses Microsoft Graph app-folder storage behind OneDrive auth.',
        status: CloudSyncProviderStatus.missingConfiguration,
        statusMessage: 'Missing OneDrive app id or redirect URI.',
        setupHint:
            'Register a Microsoft Entra app, allow browser sign-in, then set '
            'LAKSHYA_ONEDRIVE_APP_ID and LAKSHYA_ONEDRIVE_REDIRECT_URI.',
      );
    }
    return const CloudSyncProviderDescriptor(
      id: CloudSyncProviderId.oneDrive,
      title: 'Microsoft OneDrive',
      subtitle: 'Uses Microsoft Graph app-folder storage behind OneDrive auth.',
      status: CloudSyncProviderStatus.readyForImplementation,
      statusMessage: 'OneDrive app configuration is present.',
      setupHint:
          'Next implementation step: sign in via Microsoft and store the '
          'graph in the user app folder in OneDrive.',
    );
  }
}
