import 'package:web/web.dart' as web;

import 'events.dart';
import 'framework.dart';
import 'mount.dart';

/// Hydrates a server-rendered DOM tree matching [selector] with event listeners in place.
///
/// Looks up the target DOM element via `web.document.querySelector(selector)` and
/// delegates to [hydrateElement]. Throws a [StateError] if [selector] matches no element.
///
/// ```dart
/// void main() {
///   final handle = hydrate(
///     Div(
///       className: 'interactive-card',
///       children: [
///         const H1(text: 'Server Rendered Title'),
///         Button(
///           text: 'Activate',
///           on: {'click': (e) => print('Activated')},
///         ),
///       ],
///     ),
///     '#app',
///   );
/// }
/// ```
BloomMountHandle hydrate(BloomNode root, String selector) {
  final el = web.document.querySelector(selector);
  if (el == null) {
    throw StateError('Bloom hydrate: selector "$selector" matched no element.');
  }
  return hydrateElement(root, el);
}

/// Hydrates a server-rendered DOM tree inside [element] with event listeners in place.
///
/// Walks the existing DOM children in lockstep with the [root] descriptor tree, attaching
/// event listeners and syncing attributes without destroying and recreating existing DOM nodes.
///
/// ### Hydration Eligibility
/// True in-place hydration is performed when [root] consists exclusively of static nodes:
/// - **Supported static nodes**: [TextNode] (or [Text]), [ElNode] (e.g. `Div`, `Button`, `Span`),
///   [SvgNode], [FragmentNode] (or [Fragment]), [RawHtmlNode], and [StyleNode].
/// - **Unsupported reactive/sentinel nodes**: [LiveNode] (or [Live]), [ShowNode] (or [Show]),
///   [ForEachNode] (or [ForEach]), [MountNode] (or [Mount]), [RefNode], [AnimatedNode]
///   (or [Animated]), [ContextProviderNode], [ErrorBoundaryNode], [PortalNode], and
///   [SuspenseNode] (or [Suspense]).
///
/// ### Mismatch Handling & Fallback
/// A hydration mismatch occurs when:
/// 1. The descriptor tree contains any non-static/reactive node.
/// 2. A DOM node's tag name does not match the descriptor's tag (e.g. `<p>` vs `<div>`).
/// 3. A DOM node type differs from the expected descriptor (e.g. Element vs Text node).
/// 4. Child counts differ between the descriptor tree and the actual DOM.
///
/// When a mismatch occurs, [hydrateElement] performs no destructive partial updates. Instead,
/// it safely clears [element] (`element.textContent = ''`) and falls back to a clean full mount
/// via [mountToElement].
///
/// ```dart
/// final container = web.document.getElementById('content')!;
/// final handle = hydrateElement(
///   Div(
///     className: 'container',
///     children: [
///       const H1(text: 'Welcome'),
///       Button(
///         text: 'Submit',
///         on: {'click': (e) => submitForm()},
///       ),
///     ],
///   ),
///   container,
/// );
/// ```
BloomMountHandle hydrateElement(BloomNode root, web.Element element) {
  if (_isStaticallyHydratable(root)) {
    final disposers = <void Function()>[];
    if (_hydrateStatic(root, element, disposers)) {
      return BloomMountHandle(element, disposers);
    }
    // Structural mismatch — the walk above only reads/patches attributes
    // and text content in place; it never removes or reorders DOM, so
    // falling through to the full remount below is always safe.
  }
  if (element.childNodes.length > 0) {
    element.textContent = '';
  }
  return mountToElement(root, element);
}

bool _isStaticallyHydratable(BloomNode node) {
  switch (node) {
    case TextNode():
    case RawHtmlNode():
    case StyleNode():
      return true;
    case SvgNode(:final children):
      return children.every(_isStaticallyHydratable);
    case ElNode(:final children):
      return children.every(_isStaticallyHydratable);
    case FragmentNode(:final children):
      return children.every(_isStaticallyHydratable);
    default:
      return false;
  }
}

/// Top-level entry: walks [node] against [parent]'s existing children.
/// Returns false (no DOM mutated destructively) on any structural mismatch.
bool _hydrateStatic(
  BloomNode node,
  web.Element parent,
  List<void Function()> disposers,
) {
  final cursor = _Cursor(_childNodesOf(parent));
  if (!_walk(node, cursor)) return false;
  return cursor.index == cursor.nodes.length;
}

/// Cursor over a flat, pre-snapshotted list of a DOM element's children —
/// snapshotted up front so mutating `textContent`/attributes on a reused
/// node mid-walk can't shift `nextSibling` chains out from under us.
class _Cursor {
  final List<web.Node> nodes;
  int index = 0;
  _Cursor(this.nodes);
  web.Node? get current => index < nodes.length ? nodes[index] : null;
  void advance() => index++;
}

List<web.Node> _childNodesOf(web.Element el) {
  final out = <web.Node>[];
  var c = el.firstChild;
  while (c != null) {
    out.add(c);
    c = c.nextSibling;
  }
  return out;
}

bool _walk(BloomNode node, _Cursor cursor) {
  switch (node) {
    case TextNode(:final text):
      final existing = cursor.current;
      if (existing == null || existing.nodeType != web.Node.TEXT_NODE) {
        return false;
      }
      if (existing.textContent != text) existing.textContent = text;
      cursor.advance();
      return true;

    case RawHtmlNode():
      // Trusted-HTML passthrough has no structural shape to verify against
      // the DOM node-by-node; accept whatever occupies this slot (if any)
      // as already correct, matching SSR's verbatim-passthrough contract.
      final existing = cursor.current;
      if (existing == null) return false;
      cursor.advance();
      return true;

    case StyleNode(:final css):
      final existing = cursor.current;
      if (existing == null || existing.nodeType != web.Node.ELEMENT_NODE) {
        return false;
      }
      final el = existing as web.Element;
      if (el.tagName.toLowerCase() != 'style') return false;
      if (el.textContent != css) el.textContent = css;
      cursor.advance();
      return true;

    case FragmentNode(:final children):
      for (final child in children) {
        if (!_walk(child, cursor)) return false;
      }
      return true;

    // SvgNode extends ElNode, so it must be matched before the ElNode case
    // below (an object pattern matches subtypes too).
    case SvgNode(
        :final tag,
        :final text,
        :final className,
        :final style,
        :final attrs,
        :final children
      ):
      return _walkElement(cursor, tag, text, className, style, attrs, null, children);

    case ElNode(
        :final tag,
        :final text,
        :final className,
        :final style,
        :final attrs,
        :final on,
        :final children
      ):
      return _walkElement(cursor, tag, text, className, style, attrs, on, children);

    default:
      // Unreachable: hydrateElement only enters this walk when
      // _isStaticallyHydratable(node) has already excluded every other
      // BloomNode subtype from the whole tree.
      return false;
  }
}

bool _walkElement(
  _Cursor cursor,
  String tag,
  String? text,
  String? className,
  String? style,
  Map<String, String>? attrs,
  Map<String, BloomEventHandler>? on,
  List<BloomNode> children,
) {
  final existing = cursor.current;
  if (existing == null || existing.nodeType != web.Node.ELEMENT_NODE) {
    return false;
  }
  final el = existing as web.Element;
  if (el.tagName.toLowerCase() != tag.toLowerCase()) return false;

  // Sync attributes to match the descriptor — SSR output should already
  // agree, but this keeps hydration correct even if it doesn't.
  if ((className ?? '') != el.className) el.className = className ?? '';
  if (style != null) {
    el.setAttribute('style', style);
  } else if (el.hasAttribute('style')) {
    el.removeAttribute('style');
  }
  if (attrs != null) {
    for (final e in attrs.entries) {
      el.setAttribute(e.key, e.value);
    }
  }
  if (on != null) {
    for (final entry in on.entries) {
      attachBloomListener(el, entry.key, entry.value);
    }
  }

  final childCursor = _Cursor(_childNodesOf(el));
  if (text != null) {
    final firstChild = childCursor.current;
    if (firstChild == null || firstChild.nodeType != web.Node.TEXT_NODE) {
      return false;
    }
    if (firstChild.textContent != text) firstChild.textContent = text;
    childCursor.advance();
  }
  for (final child in children) {
    if (!_walk(child, childCursor)) return false;
  }
  if (childCursor.index != childCursor.nodes.length) return false;

  cursor.advance();
  return true;
}
