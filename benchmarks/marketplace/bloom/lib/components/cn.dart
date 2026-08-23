// Thin, real wiring of the two vendored class-name utilities (clsx +
// tailwind-merge) into a single `cn()` helper — the same pattern every
// shadcn/ui project reaches for. This is exactly the pattern the
// marketplace design spec's component contract assumes, and it exists so
// the Bloom side genuinely consumes the npm packages `bloom add` vendored,
// rather than hand-rolling string interpolation for every class list.
import 'dart:js_interop';

import '../src/plugins/clsx.dart' as clsx_pkg;
import '../src/plugins/tailwind_merge.dart' as tw_pkg;

/// Combines conditional class fragments (clsx) and then resolves conflicting
/// Tailwind utilities in favour of the last one that applies (tailwind-merge)
/// — e.g. `cn('px-2', condition && 'px-4')` reliably yields `px-4`, which
/// plain string interpolation with a trailing override does not guarantee
/// once class order gets shuffled by a conditional.
String cn(List<Object?> classes) {
  final merged = clsx_pkg.clsx.clsx(classes.jsify());
  if (merged == null) return '';
  final mergedStr = (merged as JSString).toDart;
  final twResult = tw_pkg.tailwind_merge.twMerge(mergedStr.toJS);
  if (twResult == null) return mergedStr;
  return (twResult as JSString).toDart;
}
