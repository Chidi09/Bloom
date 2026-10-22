/// Plain Dart class name concatenation helper for Bloom UI primitives.
///
/// Combines class names, filtering out null, false, empty, or whitespace-only
/// entries, and joins them with a single space. For known exclusive utility
/// groups, the last class with the same variant prefix wins and stays in its
/// original position relative to the remaining classes. This applies to
/// display, position, visibility, flex direction, text alignment, font weight,
/// font size, and matching value utilities in the padding, margin, width,
/// height, gap, and rounded families. For example, `cn(['hidden', 'flex'])`
/// returns `'flex'`, while `cn(['p-2', 'px-4'])` keeps both classes. Other
/// classes are never removed.
///
/// ```dart
/// cn(['hidden', isOpen ? 'inline-flex' : null, 'p-2', 'p-4']);
/// // 'inline-flex p-4'
/// ```
String cn(List<Object?> classes) {
  final results = <String?>[];
  final lastIndexByGroup = <String, int>{};
  for (final item in classes) {
    if (item == null || item == false) continue;
    final str = item.toString().trim();
    if (str.isEmpty) continue;

    for (final name in str.split(RegExp(r'\s+'))) {
      if (name.isEmpty) continue;
      final group = _exclusiveGroup(name);
      if (group != null) {
        final previousIndex = lastIndexByGroup[group];
        if (previousIndex != null) results[previousIndex] = null;
        lastIndexByGroup[group] = results.length;
      }
      results.add(name);
    }
  }
  return results.whereType<String>().join(' ');
}

const _exclusiveUtilities = <String, Set<String>>{
  'display': {
    'block',
    'inline-block',
    'inline',
    'flex',
    'inline-flex',
    'grid',
    'inline-grid',
    'hidden',
    'contents',
    'table',
  },
  'position': {'static', 'fixed', 'absolute', 'relative', 'sticky'},
  'visibility': {'visible', 'invisible', 'collapse'},
  'flex-direction': {
    'flex-row',
    'flex-row-reverse',
    'flex-col',
    'flex-col-reverse',
  },
  'text-align': {
    'text-left',
    'text-center',
    'text-right',
    'text-justify',
    'text-start',
    'text-end',
  },
  'font-weight': {
    'font-thin',
    'font-extralight',
    'font-light',
    'font-normal',
    'font-medium',
    'font-semibold',
    'font-bold',
    'font-extrabold',
    'font-black',
  },
  'font-size': {
    'text-xs',
    'text-sm',
    'text-base',
    'text-lg',
    'text-xl',
    'text-2xl',
    'text-3xl',
    'text-4xl',
    'text-5xl',
    'text-6xl',
    'text-7xl',
    'text-8xl',
    'text-9xl',
  },
};

const _valueUtilityFamilies = [
  'p-',
  'px-',
  'py-',
  'pt-',
  'pr-',
  'pb-',
  'pl-',
  'm-',
  'mx-',
  'my-',
  'mt-',
  'mr-',
  'mb-',
  'ml-',
  'w-',
  'h-',
  'gap-',
  'rounded-',
];

String? _exclusiveGroup(String utility) {
  final colon = utility.lastIndexOf(':');
  final variant = colon < 0 ? '' : utility.substring(0, colon + 1);
  final base = colon < 0 ? utility : utility.substring(colon + 1);

  for (final entry in _exclusiveUtilities.entries) {
    if (entry.value.contains(base)) return '$variant${entry.key}';
  }

  for (final family in _valueUtilityFamilies) {
    if (base.startsWith(family) && base.length > family.length) {
      // Side/axis variants (rounded-t-lg, gap-x-2) are their own group, so
      // `rounded-t-lg rounded-b-none` keeps both.
      final rest = base.substring(family.length);
      final dash = rest.startsWith('[') ? -1 : rest.lastIndexOf('-');
      return dash <= 0
          ? '$variant$family'
          : '$variant$family${rest.substring(0, dash + 1)}';
    }
  }
  return null;
}
