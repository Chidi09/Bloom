// lib/src/bloom_test.dart
//
// Component-testing utilities for bloom_js_native — analogous in spirit to
// `@testing-library/react`. Operates directly on the `BloomNode` descriptor
// tree (the same AST consumed by SSR and the browser mounter), so it needs
// no real DOM and works in a plain `dart test` run on the VM.
import 'events.dart';
import 'framework.dart';
import 'html.dart';

/// Wraps a rendered [BloomNode] tree for querying and interaction in tests.
class BloomTestRenderer {
  /// The root descriptor node under test.
  final BloomNode root;

  const BloomTestRenderer(this.root);

  /// Finds the first [ElNode] whose `data-testid` attribute equals [testId].
  /// Returns `null` if none is found.
  ElNode? queryByTestId(String testId) {
    final found = _find(root, (n) => n is ElNode && n.attrs?['data-testid'] == testId);
    return found as ElNode?;
  }

  /// Like [queryByTestId] but throws [StateError] if no match is found.
  ElNode getByTestId(String testId) {
    final found = queryByTestId(testId);
    if (found == null) {
      throw StateError('BloomTest: No element found with data-testid="$testId".');
    }
    return found;
  }

  /// Finds the first node whose own text content exactly equals [text].
  /// Matches both [TextNode] leaves and [ElNode]s using the `text` sugar
  /// field. Returns `null` if none is found.
  BloomNode? queryByText(String text) {
    return _find(root, (n) => _textOf(n) == text);
  }

  /// Like [queryByText] but throws [StateError] if no match is found.
  BloomNode getByText(String text) {
    final found = queryByText(text);
    if (found == null) {
      throw StateError('BloomTest: No element found with text "$text".');
    }
    return found;
  }

  /// Finds the first [ElNode] with the given HTML [tag] (e.g. `'button'`).
  /// Returns `null` if none is found.
  ElNode? queryByTag(String tag) {
    final found = _find(root, (n) => n is ElNode && n.tag == tag);
    return found as ElNode?;
  }

  /// Like [queryByTag] but throws [StateError] if no match is found.
  ElNode getByTag(String tag) {
    final found = queryByTag(tag);
    if (found == null) {
      throw StateError('BloomTest: No element found with tag "$tag".');
    }
    return found;
  }

  /// Renders the tree to an HTML string via the SSR backend, for
  /// snapshot-style assertions (`expect(renderer.toHtml(), contains(...))`).
  String toHtml() => renderToHtml(root);
}

/// Creates a [BloomTestRenderer] wrapping [node]. Pure Dart, no DOM required.
BloomTestRenderer renderForTest(BloomNode node) => BloomTestRenderer(node);

/// Test-only synthetic event dispatch. Invokes the target element's
/// registered handler directly (no real DOM event system involved).
class BloomFireEvent {
  const BloomFireEvent._();

  /// Fires a `click` event on [element].
  void click(ElNode element) => _dispatch(element, 'click');

  /// Fires an `input` event on [element] with the given [value].
  void input(ElNode element, {String? value}) =>
      _dispatch(element, 'input', value: value);

  /// Fires a `change` event on [element] with the given [value]/[checked].
  void change(ElNode element, {String? value, bool? checked}) =>
      _dispatch(element, 'change', value: value, checked: checked);

  /// Fires a `submit` event on [element].
  void submit(ElNode element) => _dispatch(element, 'submit');

  /// Fires an arbitrary event [type] on [element] with an optional [event]
  /// override (falls back to a minimal synthetic [BloomEvent]).
  void custom(ElNode element, String type, {BloomEvent? event}) =>
      _dispatch(element, type, override: event);

  void _dispatch(
    ElNode element,
    String type, {
    String? value,
    bool? checked,
    BloomEvent? override,
  }) {
    final handler = element.on?[type];
    if (handler == null) {
      throw StateError(
          'BloomTest: Element <${element.tag}> has no "$type" handler registered.');
    }
    handler(override ?? BloomEvent(type: type, value: value, checked: checked));
  }
}

/// Singleton event-dispatch helper. Usage: `fireEvent.click(button);`.
const fireEvent = BloomFireEvent._();

// ─── Internal tree walking ──────────────────────────────────────────────────

BloomNode? _find(BloomNode node, bool Function(BloomNode) predicate) {
  if (predicate(node)) return node;
  for (final child in _childrenOf(node)) {
    final found = _find(child, predicate);
    if (found != null) return found;
  }
  return null;
}

List<BloomNode> _childrenOf(BloomNode node) {
  return switch (node) {
    ElNode(:final children) => children,
    FragmentNode(:final children) => children,
    AnimatedNode(:final child) => [child],
    ShowNode(:final child, :final fallback) =>
      node.when() ? [child] : (fallback != null ? [fallback] : const []),
    ForEachNode() => node.buildChildren(),
    LiveNode(:final builder) => [builder()],
    MountNode(:final child) => [child],
    RefNode(:final child) => [child],
    ContextProviderNode(:final child) => [child],
    ErrorBoundaryNode(:final builder) => _safeBuild(builder),
    PortalNode(:final child) => [child],
    SuspenseNode(:final fallback) => [fallback],
    _ => const [],
  };
}

List<BloomNode> _safeBuild(BloomNode Function() builder) {
  try {
    return [builder()];
  } catch (_) {
    return const [];
  }
}

String? _textOf(BloomNode node) {
  return switch (node) {
    TextNode(:final text) => text,
    ElNode(:final text) => text,
    _ => null,
  };
}
