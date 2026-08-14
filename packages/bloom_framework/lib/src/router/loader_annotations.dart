// lib/src/router/loader_annotations.dart

/// Annotation marking a server-side or build-time data loader for a route.
class BloomLoader {
  final Duration? revalidate;

  const BloomLoader({this.revalidate});
}

/// Annotation marking a server-side or client form action handler for a route.
class BloomAction {
  const BloomAction();
}
