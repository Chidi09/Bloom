// Button variants via class-variance-authority (cva) — mirrors what the
// Next.js/shadcn side gets from the same npm package, satisfying the design
// spec's Button contract (primary / secondary / ghost / destructive) from
// one shared variant definition instead of a hand-written switch per call
// site.
import 'dart:js_interop';

import '../src/plugins/class_variance_authority.dart' as cva_pkg;

enum ButtonVariant { primary, secondary, ghost, destructive }

const _base =
    'inline-flex items-center justify-center gap-1.5 rounded-[10px] text-sm font-medium '
    'transition-shadow focus-visible:outline-none focus-visible:ring-2 '
    'focus-visible:ring-[var(--brand-600)] focus-visible:ring-offset-2 '
    'disabled:opacity-50 disabled:pointer-events-none px-4 py-2';

final _variantConfig = <String, String>{
  'primary': 'bg-[var(--brand-600)] text-white hover:bg-[var(--brand-700)]',
  'secondary':
      'bg-[var(--bg-muted)] text-[var(--text)] hover:bg-[var(--border)]',
  'ghost': 'bg-transparent text-[var(--text)] hover:bg-[var(--bg-muted)]',
  'destructive': 'bg-[#DC2626] text-white hover:bg-[#B91C1C]',
}.map((k, v) => MapEntry(k, v.jsify()));

/// Resolves a button's class list from its variant via the vendored `cva`
/// package. `cva(base, config)` itself returns a *function* — it does not
/// take the chosen variant as a third argument — so that returned function
/// has to be invoked separately with the props object to get the class
/// string back. Skipping that second call is the mistake that would make
/// this binding look wired up while silently never running cva's variant
/// resolution at all.
String buttonClasses(ButtonVariant variant) {
  final config = {
    'variants': {
      'variant': _variantConfig,
    },
    'defaultVariants': {'variant': 'primary'},
  }.jsify();

  final variantFn = cva_pkg.class_variance_authority(_base.toJS, config);
  if (variantFn == null) return _base;

  final result =
      (variantFn as JSFunction).callAsFunction(null, {'variant': variant.name}.jsify());
  if (result == null) return _base;
  return (result as JSString).toDart;
}
