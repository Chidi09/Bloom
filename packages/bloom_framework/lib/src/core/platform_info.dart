// lib/src/core/platform_info.dart
import 'platform_info_stub.dart' if (dart.library.io) 'platform_info_io.dart' as impl;

/// Returns current Dart SDK version (or 'web' on web platform).
String getDartSdkVersion() => impl.getDartSdkVersion();

/// Returns current operating system identifier.
String getOperatingSystem() => impl.getOperatingSystem();

/// Returns current operating system version string.
String getOperatingSystemVersion() => impl.getOperatingSystemVersion();

/// Whether dart:io is available in the current runtime environment.
bool get isIoPlatform => impl.isIoPlatform;
