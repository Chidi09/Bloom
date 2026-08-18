// lib/src/router/loader_annotations.dart

/// Annotation marking a server-side or build-time data loader for a route.
class BloomLoader {
  /// Optional cache revalidation interval duration.
  final Duration? revalidate;

  /// Creates a [BloomLoader] annotation with an optional [revalidate] duration.
  const BloomLoader({this.revalidate});
}

/// Annotation marking a server-side or client form action handler for a route.
class BloomAction {
  /// Creates a [BloomAction] annotation.
  const BloomAction();
}
