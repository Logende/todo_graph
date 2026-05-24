import '../service/schema_validator.dart';
import 'graph_repository.dart';

/// Non-web (native / desktop / mobile) stub. The File System Access API is a
/// browser-only feature, so on every other platform this class refuses to
/// build a file-backed repository. main.dart's platform routing handles
/// native persistence separately.
class WebGraphFileSync {
  const WebGraphFileSync();

  bool get isSupported => false;

  Future<GraphRepository?> tryRestoreRepository({
    required SchemaValidator validator,
  }) async =>
      null;

  Future<GraphRepository?> pickFileAsBackingStore({
    required SchemaValidator validator,
    required String suggestedName,
  }) async =>
      null;

  Future<GraphRepository?> openFileAsBackingStore({
    required SchemaValidator validator,
  }) async =>
      null;

  Future<void> forget() async {}

  Future<String?> currentFileName() async => null;
}
