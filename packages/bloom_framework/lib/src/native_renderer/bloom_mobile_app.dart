import 'package:flutter/material.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import '../native_engine/native_renderer.dart';

/// Top-level mobile application wrapper that mounts a Bloom JS Native AST tree into a native mobile app.
class BloomMobileApp extends StatelessWidget {
  final BloomNode home;
  final String title;

  const BloomMobileApp({
    super.key,
    required this.home,
    this.title = 'Bloom Native Mobile',
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09090B),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF09090B),
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF14141A),
        ),
        fontFamily: 'sans-serif',
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF09090B),
        body: SafeArea(
          child: SingleChildScrollView(
            child: BloomNativeRenderer(node: home),
          ),
        ),
      ),
    );
  }
}

/// Mounts and runs a pure-Dart Bloom AST descriptor tree as a native mobile application.
void runBloomMobile(BloomNode rootNode, {String title = 'Bloom Mobile App'}) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BloomMobileApp(home: rootNode, title: title));
}
