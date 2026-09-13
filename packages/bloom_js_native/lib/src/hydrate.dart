import 'package:web/web.dart' as web;

import 'framework.dart';
import 'hydration_contract.dart';
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
/// Matches SSR boundary markers (`<!--bloom:live-->`, `<!--bloom:show-->`,
/// `<!--bloom:foreach-->` with `<!--bloom:key=...-->` items, `<!--bloom:memo-->`,
/// `<!--bloom:error-boundary-->`, `<!--bloom:suspense-->`, and streaming
/// `<div id="bloom-suspense-N">` shells) to the [root] descriptor tree and
/// attaches reactive behavior to the existing DOM nodes. Signal updates after
/// hydration patch the adopted nodes; pre-hydration input values, focus, and
/// text selection are preserved.
///
/// ### Supported nodes
/// Static nodes ([TextNode], [ElNode] incl. `SvgNode`, [FragmentNode],
/// [RawHtmlNode], [StyleNode]) hydrate in place. Reactive boundaries
/// ([LiveNode], [MemoNode], [ShowNode], keyed and unkeyed [ForEachNode],
/// [SuspenseNode], [ErrorBoundaryNode]) hydrate inside their SSR markers and
/// stay reactive. Transparent wrappers ([ContextProviderNode], [MountNode]
/// which fires `onMount`, [RefNode] which attaches, [AnimatedNode]) hydrate
/// through to their content.
///
/// ### Mismatch handling
/// Each mismatch recovers at the smallest marker-delimited boundary (clear +
/// remount inside that boundary) and is reported as a [HydrationMismatch]
/// through `onMismatch`, [bloomHydrationMismatchHandler], and DevTools.
/// Only a root-level structural mismatch falls back to clearing [element]
/// and doing a clean full mount via [mountToElement]. Pass [onMismatch] to
/// observe diagnostics in development.
///
/// ### Remaining full-remount cases
/// Markerless legacy SSR output that no longer matches positionally, portal
/// `<template>` content (remounted into its target; surrounding DOM is kept),
/// and Suspense resolved-before-hydrate content (remounted as a live Suspense
/// region; dehydrated query caches resolve it instantly).
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
BloomMountHandle hydrateElement(
  BloomNode root,
  web.Element element, {
  HydrationMismatchHandler? onMismatch,
}) =>
    hydrateToElement(root, element, onMismatch: onMismatch);
