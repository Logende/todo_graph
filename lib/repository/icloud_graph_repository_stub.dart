import '../model/lakshya_graph.dart';
import '../service/cloud_sync_config.dart';
import 'graph_repository.dart';

class ICloudGraphRepository implements GraphRepository {
  @override
  Future<LakshyaGraph?> load() async => null;

  @override
  Future<void> save(LakshyaGraph graph) async {
    throw UnsupportedError('CloudKit sync is only available on the web build.');
  }
}

Future<ICloudGraphRepository> connectICloudGraphRepository(
  CloudSyncConfig config,
) async {
  throw UnsupportedError(
    'CloudKit sync is only available on the web build.',
  );
}
