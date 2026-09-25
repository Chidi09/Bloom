/// SSR/hydration boundary-marker contract for reactive DOM hydration.
///
/// Server rendering ([renderToHtml] and friends) wraps reactive subtrees in
/// HTML comment markers. Browser hydration ([hydrateElement]) matches those
/// markers to the descriptor tree and attaches reactive behavior to the
/// existing DOM nodes instead of discarding and remounting them.
///
/// Pure Dart — safe to import from server, VM, and browser code.
///
/// ### Marker format
/// Markers are HTML comments so they never affect layout or styling:
/// ```html
/// <!--bloom:live--><p>Count: 0</p><!--/bloom:live-->
/// ```
/// Mount sentinels use the same labels with surrounding spaces
/// (`<!-- bloom:live -->`); matching is whitespace-insensitive, so either
/// form hydrates.
///
/// ### Supported boundaries
/// `live`, `memo`, `show`, `foreach`, `error-boundary`, `suspense`.
/// Keyed `foreach` additionally tags each item:
/// ```html
/// <!--bloom:foreach-->
/// <!--bloom:key=user-1--><li>Alice</li><!--/bloom:key-->
/// <!--bloom:key=user-2--><li>Bob</li><!--/bloom:key-->
/// <!--/bloom:foreach-->
/// ```
/// Transparent wrappers (`ContextProvider`, `Mount`, `Ref`) emit no markers;
/// `Animated` keeps its wrapper `<div>`; `Portal` keeps its `<template>`;
/// streaming Suspense keeps its `<div id="bloom-suspense-N">` shell.
library;

import 'dart:convert';

/// Boundary label for [LiveNode].
const String hydrationMarkerLive = 'bloom:live';

/// Boundary label for [MemoNode].
const String hydrationMarkerMemo = 'bloom:memo';

/// Boundary label for [ShowNode].
const String hydrationMarkerShow = 'bloom:show';

/// Boundary label for [ForEachNode].
const String hydrationMarkerForEach = 'bloom:foreach';

/// Boundary label for [ErrorBoundaryNode].
const String hydrationMarkerErrorBoundary = 'bloom:error-boundary';

/// Boundary label for [SuspenseNode] in synchronous SSR output.
const String hydrationMarkerSuspense = 'bloom:suspense';

/// Marker label prefix for keyed `ForEach` items (`bloom:key=<escaped>`).
const String hydrationMarkerKeyPrefix = 'bloom:key=';

/// Closing marker label prefix for keyed `ForEach` items.
const String hydrationMarkerKeyClose = '/bloom:key';

/// Opening SSR marker comment for boundary [label].
///
/// ```dart
/// ssrOpenMarker('bloom:live') // '<!--bloom:live-->'
/// ```
String ssrOpenMarker(String label) => '<!--$label-->';

/// Closing SSR marker comment for boundary [label].
///
/// ```dart
/// ssrCloseMarker('bloom:live') // '<!--/bloom:live-->'
/// ```
String ssrCloseMarker(String label) => '<!--/$label-->';

/// Opening SSR marker for a keyed `ForEach` item with [key].
String ssrKeyOpenMarker(String key) =>
    '<!--$hydrationMarkerKeyPrefix${escapeHydrationKey(key)}-->';

/// Closing SSR marker for a keyed `ForEach` item.
String ssrKeyCloseMarker() => '<!--$hydrationMarkerKeyClose-->';

/// Normalizes raw comment [data] for marker comparison.
///
/// Trims whitespace so SSR output (`bloom:live`) and mount sentinels
/// (` bloom:live `) match identically.
String normalizeMarkerData(String data) => data.trim();

/// Whether normalized comment [data] opens boundary [label].
bool isMarkerOpen(String data, String label) =>
    normalizeMarkerData(data) == label;

/// Whether normalized comment [data] closes boundary [label].
bool isMarkerClose(String data, String label) =>
    normalizeMarkerData(data) == '/$label';

/// Extracts the escaped key from a `bloom:key=<escaped>` marker, or `null`.
String? parseKeyMarker(String data) {
  final normalized = normalizeMarkerData(data);
  if (normalized.startsWith(hydrationMarkerKeyPrefix)) {
    try {
      return unescapeHydrationKey(
          normalized.substring(hydrationMarkerKeyPrefix.length));
    } on FormatException {
      // SSR output can be modified by an intermediary or contain hand-authored
      // raw HTML. Treat a corrupt marker as a hydration mismatch, not a crash.
      return null;
    }
  }
  return null;
}

/// Whether normalized comment [data] closes a keyed item marker.
bool isKeyMarkerClose(String data) =>
    normalizeMarkerData(data) == hydrationMarkerKeyClose;

/// Escapes an item [key] for embedding in an HTML comment marker.
///
/// Keys using `[A-Za-z0-9_:.~-]` pass through verbatim for readability.
/// Anything else (spaces, `--`, `<`, `>`, unicode) is base64url-encoded with
/// a `b64:` prefix so markers can never break out of the comment.
String escapeHydrationKey(String key) {
  if (key.isNotEmpty &&
      RegExp(r'^[A-Za-z0-9_:.~-]+$').hasMatch(key) &&
      !key.contains('--')) {
    return key;
  }
  // UTF-8 first: base64 over raw UTF-16 code units truncates anything
  // outside Latin-1 (CJK, emoji), so those keys never matched on hydrate.
  return 'b64:${base64Url.encode(utf8.encode(key))}';
}

/// Reverses [escapeHydrationKey].
String unescapeHydrationKey(String escaped) {
  if (escaped.startsWith('b64:')) {
    return utf8.decode(base64Url.decode(escaped.substring(4)));
  }
  return escaped;
}

/// Streaming Suspense placeholder element id for boundary [index].
///
/// ```dart
/// suspenseStreamId(0) // 'bloom-suspense-0'
/// ```
String suspenseStreamId(int index) => 'bloom-suspense-$index';

/// Attribute hydration sets on a claimed streaming Suspense shell.
///
/// When hydration claims `<div id="bloom-suspense-N">`, it moves the id to
/// this attribute so a late-arriving server patch script
/// (`document.getElementById("bloom-suspense-N")`, null-guarded) safely
/// no-ops instead of destroying hydrated listeners and effects. The client
/// Suspense region re-runs its own `resource` and patches itself on resolve.
const String suspenseClaimedAttribute = 'data-bloom-ssr-suspense';

/// Describes a single hydration mismatch and the recovery applied.
///
/// Reported through the hydration mismatch handler and DevTools instead of
/// throwing, so one bad boundary never breaks the whole page.
class HydrationMismatch {
  /// Slash-separated descriptor path, e.g. `Div[1]/LiveNode/P`.
  final String path;

  /// Nearest marker-delimited boundary, e.g. `bloom:live`, or `'root'`.
  final String boundary;

  /// What hydration expected, e.g. `element <p>`.
  final String expected;

  /// What the DOM actually held, e.g. `element <div>` or `missing marker`.
  final String actual;

  /// Recovery taken, e.g. `remounted boundary` or `remounted target`.
  final String recovery;

  /// Creates a hydration mismatch record.
  const HydrationMismatch({
    required this.path,
    required this.boundary,
    required this.expected,
    required this.actual,
    required this.recovery,
  });

  @override
  String toString() => formatHydrationMismatch(this);
}

/// Formats [mismatch] as a single-line development diagnostic.
String formatHydrationMismatch(HydrationMismatch mismatch) =>
    'Bloom hydration mismatch at ${mismatch.path} '
    '[boundary ${mismatch.boundary}]: expected ${mismatch.expected}, '
    'found ${mismatch.actual} — ${mismatch.recovery}.';
