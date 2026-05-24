import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'external_url_opener_platform_stub.dart'
    if (dart.library.io) 'external_url_opener_platform_io.dart';

typedef LaunchUrlFn = Future<bool> Function(
  Uri uri, {
  LaunchMode mode,
  WebViewConfiguration webViewConfiguration,
  BrowserConfiguration browserConfiguration,
  String? webOnlyWindowName,
});
typedef PlatformFallbackOpenFn = Future<String?> Function(String url);

/// Small service wrapper so URL launching can be tested and given a
/// platform-specific fallback when the plugin is unavailable at runtime.
class ExternalUrlOpener {
  const ExternalUrlOpener({
    this.launch = launchUrl,
    this.platformFallbackOpen = openUrlWithPlatformFallback,
  });

  final LaunchUrlFn launch;
  final PlatformFallbackOpenFn platformFallbackOpen;

  Future<String?> open(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (!_isLaunchableUri(uri)) return 'Not a valid URL: $rawUrl';
    final launchableUri = uri!;
    try {
      final launched = await launch(
        launchableUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return null;
      return 'No application is registered to open this URL. For obsidian:// '
          'links, make sure Obsidian is installed and the vault is mounted.';
    } on MissingPluginException {
      final fallbackError = await platformFallbackOpen(rawUrl);
      if (fallbackError == null) return null;
      return 'URL opening is not available in this running app build yet. '
          'Fully quit and relaunch the app after rebuilding so the desktop '
          'plugin is registered.\n\n'
          'Fallback attempt result: $fallbackError';
    } catch (e) {
      return 'Could not open URL: $e';
    }
  }

  bool _isLaunchableUri(Uri? uri) {
    if (uri == null || !uri.hasScheme) return false;
    return switch (uri.scheme) {
      'http' || 'https' => uri.host.isNotEmpty,
      _ => true,
    };
  }
}
