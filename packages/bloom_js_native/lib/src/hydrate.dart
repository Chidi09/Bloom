import 'package:web/web.dart' as web;

import 'framework.dart';
import 'mount.dart';

/// Hydrates a server-rendered DOM tree with reactive listeners in-place.
///
/// Walks the existing DOM children of the element matched by [selector]
/// without re-creating or replacing existing HTML elements.
BloomMountHandle hydrate(BloomNode root, String selector) {
  final el = web.document.querySelector(selector);
  if (el == null) {
    throw StateError('Bloom hydrate: selector "$selector" matched no element.');
  }
  return hydrateElement(root, el);
}

/// Hydrates into a specific pre-rendered [Element].
///
/// Current implementation: a full client-side re-mount rather than a true
/// node-reuse hydration (React's `hydrateRoot` walks the existing DOM and
/// attaches listeners in place without recreating nodes; that algorithm is
/// not yet implemented here — tracked as a follow-up). This still produces
/// a *correct* result — existing server-rendered content is cleared first,
/// so calling this on a non-empty root does not duplicate content the way
/// blindly delegating to [mountToElement] would (which only ever appends).
BloomMountHandle hydrateElement(BloomNode root, web.Element element) {
  if (element.childNodes.length > 0) {
    element.textContent = '';
  }
  return mountToElement(root, element);
}
