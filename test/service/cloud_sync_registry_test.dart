import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/service/cloud_sync_config.dart';
import 'package:lakshya/service/cloud_sync_provider.dart';
import 'package:lakshya/service/cloud_sync_registry.dart';

void main() {
  test('describes the OneDrive provider', () {
    final registry = CloudSyncRegistry(
      config: const CloudSyncConfig(isWeb: true),
    );

    final descriptors = registry.describeAll();

    expect(descriptors.map((d) => d.id), [CloudSyncProviderId.oneDrive]);
  });

  test('OneDrive becomes ready when app config is present', () {
    final registry = CloudSyncRegistry(
      config: const CloudSyncConfig(
        isWeb: true,
        oneDriveAppId: 'client-id',
        oneDriveRedirectUri: 'https://logende.github.io/todo_graph/',
      ),
      providers: const [OneDriveCloudSyncProvider()],
    );

    final descriptor = registry.describeAll().single;

    expect(
      descriptor.status,
      CloudSyncProviderStatus.readyForImplementation,
    );
  });

  test('OneDrive reports missing config by default', () {
    final registry = CloudSyncRegistry(
      config: const CloudSyncConfig(isWeb: true),
      providers: const [OneDriveCloudSyncProvider()],
    );

    final descriptor = registry.describeAll().single;

    expect(
      descriptor.status,
      CloudSyncProviderStatus.missingConfiguration,
    );
  });
}
