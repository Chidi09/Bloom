/// Declarative route data loader and form action annotations.
library;

/// Annotation marking a server-side or build-time data loader for a route.
///
/// Loaders execute before rendering to fetch required data asynchronously.
///
/// Example:
/// ```dart
/// @BloomLoader(revalidate: Duration(minutes: 5))
/// Future<PostData> loadPost(BloomRouteContext ctx) async {
///   return fetchPost(ctx.params['id']!);
/// }
/// ```
class BloomLoader {
  /// Optional cache revalidation interval duration for SSG/ISR rendering.
  final Duration? revalidate;

  /// Creates a [BloomLoader] annotation with an optional [revalidate] duration.
  const BloomLoader({this.revalidate});
}

/// Annotation marking a server-side or client form action handler for a route.
///
/// Actions handle mutations, form submissions, and user interactions.
///
/// Example:
/// ```dart
/// @BloomAction()
/// Future<ActionResult> updateProfile(BloomRouteContext ctx) async {
///   // Update user profile
///   return ActionResult.success();
/// }
/// ```
class BloomAction {
  /// Creates a [BloomAction] annotation.
  const BloomAction();
}

