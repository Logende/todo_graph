import 'dart:io';

Future<String?> openUrlWithPlatformFallback(String url) async {
  if (!Platform.isMacOS) {
    return 'URL opening is not available in this app build yet.';
  }
  final result = await Process.run('open', [url]);
  if (result.exitCode == 0) return null;
  final stderrText = result.stderr.toString().trim();
  final stdoutText = result.stdout.toString().trim();
  final detail = stderrText.isNotEmpty ? stderrText : stdoutText;
  return detail.isEmpty ? 'macOS could not open this URL.' : detail;
}
