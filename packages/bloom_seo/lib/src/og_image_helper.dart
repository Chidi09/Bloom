// lib/src/og_image_helper.dart

/// Helper for building standard Open Graph image asset paths.
///
/// This pure utility computes the URL path to a generated social card PNG
/// (e.g. `'/generated/og/home.png'`), which can be assigned to
/// `HeadManager.ogImage` or `HeadManager.image`.
///
/// Note: This is an optional convenience helper and is NOT forcibly coupled
/// to `HeadManager`.
///
/// Example:
/// ```dart
/// head.ogImage.value = ogImagePath(slug: 'home');
/// ```
String ogImagePath({
  required String slug,
  String base = '/generated/og',
}) {
  final cleanSlug = slug.startsWith('/') ? slug.substring(1) : slug;
  final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$cleanBase/$cleanSlug.png';
}
