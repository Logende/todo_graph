import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/service/external_url_opener.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('rejects invalid URLs before calling the launcher', () async {
    var called = false;
    final opener = ExternalUrlOpener(
      launch: (_, {mode = LaunchMode.platformDefault, webViewConfiguration = const WebViewConfiguration(), browserConfiguration = const BrowserConfiguration(), webOnlyWindowName}) async {
        called = true;
        return true;
      },
    );

    final error = await opener.open('not a valid url');

    expect(error, 'Not a valid URL: not a valid url');
    expect(called, isFalse);
  });

  test('returns a handler message when the launcher reports false', () async {
    final opener = ExternalUrlOpener(
      launch: (_, {mode = LaunchMode.platformDefault, webViewConfiguration = const WebViewConfiguration(), browserConfiguration = const BrowserConfiguration(), webOnlyWindowName}) async => false,
    );

    final error = await opener.open('obsidian://open?vault=test');

    expect(error, contains('No application is registered to open this URL'));
  });

  test('uses the platform fallback when the plugin is unavailable', () async {
    final opener = ExternalUrlOpener(
      launch: (_, {mode = LaunchMode.platformDefault, webViewConfiguration = const WebViewConfiguration(), browserConfiguration = const BrowserConfiguration(), webOnlyWindowName}) async {
        throw MissingPluginException('missing');
      },
      platformFallbackOpen: (_) async => null,
    );

    final error = await opener.open('https://example.com');

    expect(error, isNull);
  });

  test('surfaces fallback failure details when plugin and fallback both fail',
      () async {
    final opener = ExternalUrlOpener(
      launch: (_, {mode = LaunchMode.platformDefault, webViewConfiguration = const WebViewConfiguration(), browserConfiguration = const BrowserConfiguration(), webOnlyWindowName}) async {
        throw MissingPluginException('missing');
      },
      platformFallbackOpen: (_) async => 'macOS could not open this URL.',
    );

    final error = await opener.open('https://example.com');

    expect(error, contains('plugin is registered'));
    expect(error, contains('macOS could not open this URL.'));
  });
}
