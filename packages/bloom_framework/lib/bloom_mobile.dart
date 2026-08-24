/// Fabric-grade Native Mobile AST Engine for Bloom JS Native descriptors.
///
/// Re-exports pure Dart AST nodes from `package:bloom_js_native` alongside
/// high-performance Flutter layout render boxes, virtualized list engines, style resolvers,
/// and the root [BloomMobileApp] widget.
///
/// Example:
/// ```dart
/// import 'package:bloom_framework/bloom_mobile.dart';
///
/// void main() {
///   runApp(
///     BloomMobileApp(
///       descriptor: Div(children: [H1(text: 'Native Mobile Screen')]),
///     ),
///   );
/// }
/// ```
library bloom_mobile;

export 'package:bloom_js_native/bloom_js_native.dart';
export 'src/native_engine/flex_layout.dart';
export 'src/native_engine/input_host.dart';
export 'src/native_engine/leaf_render_box.dart';
export 'src/native_engine/native_renderer.dart';
export 'src/native_engine/style_resolver.dart';
export 'src/native_engine/virtual_list.dart';
export 'src/native_renderer/bloom_mobile_app.dart';
