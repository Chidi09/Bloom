/// Bloom JS Native Static Site Generation (SSG) library.
///
/// This VM-only library provides static site rendering for Bloom JS Native applications.
/// It renders pre-configured routes to static HTML files, copies assets, and prepares
/// deployable bundles in `dist/`.
///
/// Example `bin/ssg.dart` usage:
/// ```dart
/// import 'package:bloom_js_native/bloom_js_native.dart';
/// import 'package:bloom_js_native/ssg.dart';
///
/// void main() async {
///   final result = await generateStaticSite(
///     pages: {
///       '/': () => Div(text: 'Home page'),
///       '/about': () => Div(text: 'About page'),
///     },
///     title: 'My Bloom App',
///     titleFor: (path) => path == '/about' ? 'About Us' : 'Home',
///   );
///   print('Rendered ${result.pageCount} pages to dist/');
/// }
/// ```
library;

export 'src/ssg.dart';
