/// IO platform implementation of platform information utilities.
library;

import 'dart:io';

/// Returns the current Dart SDK version on IO platforms.
String getDartSdkVersion() => Platform.version.split(' ').first;

/// Returns the operating system identifier on IO platforms.
String getOperatingSystem() => Platform.operatingSystem;

/// Returns the operating system version string on IO platforms.
String getOperatingSystemVersion() => Platform.operatingSystemVersion;

/// Always returns `true` on IO platforms.
bool get isIoPlatform => true;

