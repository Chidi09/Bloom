/// Cross-platform runtime environment inspection utilities.
library;

import 'platform_info_stub.dart' if (dart.library.io) 'platform_info_io.dart' as impl;

/// Returns current Dart SDK version (or `'web'` on web platforms).
///
/// Example:
/// ```dart
/// final sdk = getDartSdkVersion();
/// ```
String getDartSdkVersion() => impl.getDartSdkVersion();

/// Returns current operating system identifier (e.g. `'android'`, `'ios'`, `'linux'`, `'macos'`, `'windows'`, or `'web'`).
///
/// Example:
/// ```dart
/// final os = getOperatingSystem();
/// ```
String getOperatingSystem() => impl.getOperatingSystem();

/// Returns current operating system version string.
///
/// Example:
/// ```dart
/// final osVer = getOperatingSystemVersion();
/// ```
String getOperatingSystemVersion() => impl.getOperatingSystemVersion();

/// Whether `dart:io` is available in the current runtime environment.
///
/// Returns `false` when compiled for Web browsers.
bool get isIoPlatform => impl.isIoPlatform;

