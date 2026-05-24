import 'dart:io';

import '../model/lakshya_graph.dart';
import 'graph_io.dart';

/// File-based import/export helpers used by desktop platforms.
class DesktopGraphFileIo {
  DesktopGraphFileIo({required this.graphIo});

  final GraphIo graphIo;

  Future<void> exportToFile({
    required LakshyaGraph graph,
    required String path,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(graphIo.exportToJson(graph));
  }

  Future<LakshyaGraph> importFromFile(String path) async {
    final text = await File(path).readAsString();
    return graphIo.importFromJson(text);
  }
}
