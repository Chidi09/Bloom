import '../framework.dart';

/// Renders an inline SVG icon for Bloom UI primitives.
///
/// Clean vector icon map avoiding toy emojis or external icon fonts.
String iconSvgString(String name, {String className = 'w-4 h-4'}) {
  final paths = <String, String>{
    'check': '<path d="M5 13l4 4L19 7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'x': '<path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'minus': '<path d="M5 12h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'plus': '<path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'chevron-down': '<path d="M6 9l6 6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'chevron-up': '<path d="M18 15l-6-6-6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'chevron-left': '<path d="M15 18l-6-6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'chevron-right': '<path d="M9 18l6-6-6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'search': '<path d="M21 21l-4.35-4.35M19 11a8 8 0 11-16 0 8 8 0 0116 0z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'circle': '<circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"/>',
    'circle-filled': '<circle cx="12" cy="12" r="5" fill="currentColor"/>',
    'info': '<circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/><path d="M12 16v-4M12 8h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    'alert': '<path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0zM12 9v4M12 17h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'spinner': '<path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'dots-horizontal': '<path d="M5 12h.01M12 12h.01M19 12h.01" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>',
  };

  final pathData = paths[name] ?? paths['info']!;
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" class="$className" aria-hidden="true">$pathData</svg>';
}

/// Helper returning a BloomNode for an icon name.
BloomNode uiIcon(String name, {String className = 'w-4 h-4'}) =>
    Raw(iconSvgString(name, className: className));
