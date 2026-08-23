// lib/src/bloom_test.dart
//
// Component-testing utilities for bloom_js_native — analogous in spirit to
// `@testing-library/react`. Operates directly on the `BloomNode` descriptor
// tree (the same AST consumed by SSR and the browser mounter), so it needs
// no real DOM and works in a plain `dart test` run on the VM.
import 'events.dart';
import 'framework.dart';
import 'html.dart';

/// Test harness wrapping a [BloomNode] AST tree for querying and assertion in VM tests.
///
/// Enables testing of Bloom components in standard `dart test` environments on the Dart VM
/// without requiring a browser DOM, JS runtime, or Flutter engine.
///
/// Provides querying utilities (`queryBy*` and `getBy*`) that traverse the descriptor hierarchy,
/// inspect attributes and text content, and support snapshot verification via [toHtml].
///
/// ```dart
/// BloomNode counterComponent(Signal<int> count) => Div(
///   attrs: {'data-testid': 'counter-root'},
///   children: [
///     Live(() => Span(attrs: {'data-testid': 'count-val'}, text: 'Count: ${count.value}')),
///     Button(
///       attrs: {'data-testid': 'inc-btn'},
///       onClick: (_) => count.value++,
///       text: 'Increment',
///     ),
///   ],
/// );
///
/// void main() {
///   test('increments counter on click', () {
///     final count = signal(0);
///     final renderer = renderForTest(counterComponent(count));
///
///     expect(renderer.getByTestId('count-val').text, 'Count: 0');
///
///     final btn = renderer.getByTestId('inc-btn');
///     fireEvent.click(btn);
///
///     expect(count.value, 1);
///   });
/// }
/// ```
class BloomTestRenderer {
  /// The root descriptor node under test.
  final BloomNode root;

  /// Creates a test renderer wrapping [root].
  const BloomTestRenderer(this.root);

  /// Finds the first [ElNode] in the tree whose `data-testid` attribute matches [testId].
  ///
  /// Returns `null` if no matching element is found.
  ElNode? queryByTestId(String testId) {
    final found = _find(root, (n) => n is ElNode && n.attrs?['data-testid'] == testId);
    return found as ElNode?;
  }

  /// Finds the first [ElNode] in the tree whose `data-testid` attribute matches [testId].
  ///
  /// Throws [StateError] if no matching element is found.
  ElNode getByTestId(String testId) {
    final found = queryByTestId(testId);
    if (found == null) {
      throw StateError('BloomTest: No element found with data-testid="$testId".');
    }
    return found;
  }

  /// Finds the first node whose direct text content equals [text].
  ///
  /// Matches both [TextNode] leaf nodes and [ElNode] elements utilizing the `text` parameter.
  /// Returns `null` if no matching node is found.
  BloomNode? queryByText(String text) {
    return _find(root, (n) => _textOf(n) == text);
  }

  /// Finds the first node whose direct text content equals [text].
  ///
  /// Matches both [TextNode] leaf nodes and [ElNode] elements utilizing the `text` parameter.
  /// Throws [StateError] if no matching node is found.
  BloomNode getByText(String text) {
    final found = queryByText(text);
    if (found == null) {
      throw StateError('BloomTest: No element found with text "$text".');
    }
    return found;
  }

  /// Finds the first [ElNode] whose HTML tag matches [tag] (e.g. `'button'`, `'div'`).
  ///
  /// Returns `null` if no matching element is found.
  ElNode? queryByTag(String tag) {
    final found = _find(root, (n) => n is ElNode && n.tag == tag);
    return found as ElNode?;
  }

  /// Finds the first [ElNode] whose HTML tag matches [tag] (e.g. `'button'`, `'div'`).
  ///
  /// Throws [StateError] if no matching element is found.
  ElNode getByTag(String tag) {
    final found = queryByTag(tag);
    if (found == null) {
      throw StateError('BloomTest: No element found with tag "$tag".');
    }
    return found;
  }

  /// Evaluates the tree through the SSR renderer and returns its rendered HTML string.
  ///
  /// Useful for snapshot and substring assertions in tests.
  ///
  /// ```dart
  /// expect(renderer.toHtml(), contains('<button type="submit">'));
  /// ```
  String toHtml() => renderToHtml(root);
}

/// Creates a [BloomTestRenderer] wrapping [node] for headless VM unit testing.
///
/// ```dart
/// final renderer = renderForTest(myComponent());
/// ```
BloomTestRenderer renderForTest(BloomNode node) => BloomTestRenderer(node);

/// Synthetic event dispatcher for simulating DOM events in headless VM unit tests.
///
/// Invokes the corresponding [BloomEventHandler] registered in [ElNode.on] directly
/// with a synthetic [BloomEvent] instance.
class BloomFireEvent {
  const BloomFireEvent._();

  /// Fires a synthetic `click` event on [element].
  ///
  /// Throws [StateError] if [element] has no `'click'` handler registered.
  void click(ElNode element) => _dispatch(element, 'click');

  /// Fires a synthetic `input` event on [element] with the specified text [value].
  ///
  /// Throws [StateError] if [element] has no `'input'` handler registered.
  void input(ElNode element, {String? value}) =>
      _dispatch(element, 'input', value: value);

  /// Fires a synthetic `change` event on [element] with [value] or [checked] state.
  ///
  /// Throws [StateError] if [element] has no `'change'` handler registered.
  void change(ElNode element, {String? value, bool? checked}) =>
      _dispatch(element, 'change', value: value, checked: checked);

  /// Fires a synthetic `submit` event on [element].
  ///
  /// Throws [StateError] if [element] has no `'submit'` handler registered.
  void submit(ElNode element) => _dispatch(element, 'submit');

  /// Fires a synthetic event of arbitrary [type] on [element] with an optional custom [event] payload.
  ///
  /// Throws [StateError] if [element] has no handler registered for [type].
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

/// Global synthetic event dispatcher for headless VM unit tests.
///
/// ```dart
/// final btn = renderer.getByTestId('submit-btn');
/// fireEvent.click(btn);
/// ```
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
