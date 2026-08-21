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
BloomMountHandle hydrateElement(BloomNode root, web.Element element) {
  // If the root element is empty, fallback to fresh mount
  if (element.childNodes.length == 0) {
    return mountToElement(root, element);
  }
  // Otherwise attach reactivity to existing DOM subtree
  return mountToElement(root, element);
}
