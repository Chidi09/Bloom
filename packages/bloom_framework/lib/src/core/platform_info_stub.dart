/// Web/fallback stub implementation of platform information utilities.
library;

/// Returns `'web'` on browser platforms.
String getDartSdkVersion() => 'web';

/// Returns `'web'` on browser platforms.
String getOperatingSystem() => 'web';

/// Returns `'browser'` on browser platforms.
String getOperatingSystemVersion() => 'browser';

/// Always returns `false` on web/stub platforms.
bool get isIoPlatform => false;

