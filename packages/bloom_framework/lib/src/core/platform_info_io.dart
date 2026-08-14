// lib/src/core/platform_info_io.dart
import 'dart:io';

String getDartSdkVersion() => Platform.version.split(' ').first;
String getOperatingSystem() => Platform.operatingSystem;
String getOperatingSystemVersion() => Platform.operatingSystemVersion;
bool get isIoPlatform => true;
