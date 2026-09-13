import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:einthusan_tv/main.dart';
import 'package:einthusan_tv/screens/tv_browser_screen.dart';

class TestWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return TestWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return TestWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return TestNavigationDelegate(params);
  }
}

class TestWebViewController extends PlatformWebViewController {
  TestWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setUserAgent(String? userAgent) async {}

  @override
  Future<void> setBackgroundColor(dynamic color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<bool> canGoForward() async => false;

  @override
  Future<void> runJavaScript(String javaScript) async {}
}

class TestWebViewWidget extends PlatformWebViewWidget {
  TestWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

class TestNavigationDelegate extends PlatformNavigationDelegate {
  TestNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}

void main() {
  setUp(() {
    WebViewPlatform.instance = TestWebViewPlatform();
  });

  testWidgets('Einthusan TV app renders TvBrowserScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const EinthusanTvApp());
    expect(find.byType(TvBrowserScreen), findsOneWidget);
  });
}
