import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/service/cloud_sync_config.dart';
import 'package:lakshya/service/cloud_sync_provider.dart';
import 'package:lakshya/service/cloud_sync_registry.dart';

void main() {
  test('describes all three cloud providers', () {
    final registry = CloudSyncRegistry(
      config: const CloudSyncConfig(isWeb: true),
    );

    final descriptors = registry.describeAll();

    expect(descriptors.map((d) => d.id), [
      CloudSyncProviderId.iCloud,
      CloudSyncProviderId.dropbox,
      CloudSyncProviderId.oneDrive,
    ]);
  });

  test('iCloud becomes ready when CloudKit config is present', () {
    final registry = CloudSyncRegistry(
      config: const CloudSyncConfig(
        isWeb: true,
        iCloudContainerId: 'iCloud.example.todo',
        iCloudApiToken: 'token',
      ),
      providers: const [ICloudCloudSyncProvider()],
    );

    final descriptor = registry.describeAll().single;

    expect(
      descriptor.status,
      CloudSyncProviderStatus.readyForImplementation,
    );
  });

  test('Dropbox and OneDrive report missing config by default', () {
    final registry = CloudSyncRegistry(
      config: const CloudSyncConfig(isWeb: true),
      providers: const [
        DropboxCloudSyncProvider(),
        OneDriveCloudSyncProvider(),
      ],
    );

    final descriptors = registry.describeAll();

    expect(
      descriptors[0].status,
      CloudSyncProviderStatus.missingConfiguration,
    );
    expect(
      descriptors[1].status,
      CloudSyncProviderStatus.missingConfiguration,
    );
  });
}
