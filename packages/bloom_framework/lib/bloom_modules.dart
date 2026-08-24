/// Native Module platform and DSL for Bloom applications.
///
/// Exports annotations, manifests, native module registries, and custom native view bindings
/// for bridging platform-specific Swift, Kotlin, and C++ capabilities into Bloom.
///
/// Example:
/// ```dart
/// import 'package:bloom_framework/bloom_modules.dart';
///
/// @BloomModule(name: 'Biometrics')
/// class BiometricsModule extends NativeModule {
///   // Module implementation
/// }
/// ```
library bloom_modules;

export 'src/modules/annotations.dart';
export 'src/modules/exceptions.dart';
export 'src/modules/manifest.dart';
export 'src/modules/native_module.dart';
export 'src/modules/module_registry.dart';
export 'src/modules/native_view.dart';
