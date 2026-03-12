import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MaterialApp(home: DashMealsApp()));
}

class DashMealsApp extends StatefulWidget {
  const DashMealsApp({super.key});

  @override
  State<DashMealsApp> createState() => _DashMealsAppState();
}

class _DashMealsAppState extends State<DashMealsApp> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadFlutterAsset('assets/www/index.html');
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
