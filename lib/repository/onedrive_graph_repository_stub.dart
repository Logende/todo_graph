import '../model/lakshya_graph.dart';
import '../service/cloud_sync_config.dart';
import 'graph_repository.dart';

class OneDriveGraphRepository implements GraphRepository {
  @override
  Future<LakshyaGraph?> load() async => null;

  @override
  Future<void> save(LakshyaGraph graph) async {
    throw UnsupportedError('OneDrive sync is only available on the web build.');
  }
}

Future<OneDriveGraphRepository> connectOneDriveGraphRepository(
  CloudSyncConfig config,
) async {
  throw UnsupportedError('OneDrive sync is only available on the web build.');
}
