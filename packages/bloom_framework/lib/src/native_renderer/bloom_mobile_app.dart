/// Native mobile host application renderer for Bloom JS Native descriptors.
library;

import 'package:flutter/material.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import '../native_engine/native_renderer.dart';

/// Top-level mobile application wrapper that mounts a Bloom JS Native AST tree into a native mobile app.
///
/// Applies Bloom's carbon-inspired dark theme and hosts the [BloomNativeRenderer] engine.
///
/// Example:
/// ```dart
/// void main() {
///   runApp(
///     BloomMobileApp(
///       home: Div(children: [H1(text: 'Hello Bloom Mobile')]),
///       title: 'Mobile App',
///     ),
///   );
/// }
/// ```
class BloomMobileApp extends StatelessWidget {
  /// The root [BloomNode] AST descriptor to render.
  final BloomNode home;

  /// Application title string.
  final String title;

  /// Creates a [BloomMobileApp] mounting [home].
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
///
/// Initializes Flutter bindings and boots [BloomMobileApp] immediately.
///
/// Example:
/// ```dart
/// void main() {
///   runBloomMobile(
///     Div(children: [Text('Hello from Bloom AST')]),
///   );
/// }
/// ```
void runBloomMobile(BloomNode rootNode, {String title = 'Bloom Mobile App'}) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BloomMobileApp(home: rootNode, title: title));
}

