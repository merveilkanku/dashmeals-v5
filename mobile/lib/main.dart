import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:app_links/app_links.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DashMealsApp(),
  ));
}

class DashMealsApp extends StatefulWidget {
  const DashMealsApp({super.key});

  @override
  State<DashMealsApp> createState() => _DashMealsAppState();
}

class _DashMealsAppState extends State<DashMealsApp> {
  late final WebViewController controller;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initWebView();
    _initDeepLinks();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.camera,
      Permission.storage,
      Permission.notification,
      Permission.photos,
    ].request();
  }

  void _initWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('DashMealsMobile')
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
          ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Intercept localhost redirects often used in OAuth
            if (request.url.startsWith('http://localhost') || request.url.startsWith('https://localhost')) {
              final uri = Uri.parse(request.url);
              // Convert localhost to our custom scheme and handle it
              final newUrl = uri.replace(scheme: 'com.dashmeals.android', host: 'callback').toString();
              _handleDeepLink(Uri.parse(newUrl));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      // domStorageEnabled is enabled by default in newer versions of webview_flutter_android

      // Handle file uploads (PDF, images, etc.)
      androidController.setOnShowFileSelector((params) async {
        try {
          final result = await FilePicker.platform.pickFiles(
            allowMultiple: params.mode == FileSelectorMode.openMultiple,
            type: FileType.any,
          );

          if (result != null && result.files.isNotEmpty) {
            return result.files
                .where((file) => file.path != null)
                .map((file) => Uri.file(file.path!).toString())
                .toList();
          }
        } catch (e) {
          debugPrint('Error picking files: $e');
        }
        return <String>[];
      });
    }

    controller.loadFlutterAsset('assets/www/index.html');
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Handle links when app is in foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Handle initial link if app was started by a link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Handling deep link: $uri');
    // We can pass the full URL to the WebView or just the fragment/query
    // Supabase redirects usually contain access_token in the fragment (#)

    // If it's an OAuth callback, we should inject it into the WebView
    // Most SPA apps handle the URL hash automatically if we just navigate to it.

    // Construct the internal URL. assets/www/index.html is the base.
    // We can try to use controller.runJavaScript to set window.location.hash
    if (uri.hasFragment || uri.query.isNotEmpty) {
      final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
      final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
      controller.runJavaScript('window.location.href = "index.html$query$fragment";');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
