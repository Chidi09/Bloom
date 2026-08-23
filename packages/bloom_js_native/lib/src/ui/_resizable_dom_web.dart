import 'package:web/web.dart' as web;

/// Browser implementation for [resolveContainerRatio] — resolves a pointer
/// position into a 0..1 split ratio against the container's own bounding rect.
double? resolveContainerRatio({
  required String containerId,
  required double clientX,
  required double clientY,
  required bool vertical,
}) {
  final el = web.document.getElementById(containerId);
  if (el == null) return null;
  final rect = el.getBoundingClientRect();
  final ratio = vertical
      ? (clientY - rect.top) / rect.height
      : (clientX - rect.left) / rect.width;
  if (ratio.isNaN || ratio.isInfinite) return null;
  return ratio;
}
