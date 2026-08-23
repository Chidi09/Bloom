import '../framework.dart';
import '../router.dart';
import 'cn.dart';
import 'icons.dart';

/// Breadcrumb navigation hierarchy primitive.
BloomNode breadcrumb(
  List<({String label, String? href})> items, {
  String extraClassName = '',
}) {
  return El(
    'nav',
    attrs: const {'aria-label': 'Breadcrumb'},
    className: extraClassName,
    children: [
      El(
        'ol',
        className: cn([
          'flex items-center gap-2 text-xs sm:text-sm text-[var(--text-muted)] flex-wrap select-none',
        ]),
        children: [
          for (var i = 0; i < items.length; i++) ...[
            El(
              'li',
              className: 'flex items-center gap-2',
              children: [
                if (items[i].href != null && i < items.length - 1)
                  Link(
                    href: items[i].href!,
                    className:
                        'hover:text-[var(--text)] transition-colors focus-visible:outline-none '
                        'focus-visible:ring-2 focus-visible:ring-[var(--ring)] rounded',
                    text: items[i].label,
                  )
                else
                  Span(
                    className:
                        'text-[var(--text)] font-medium truncate max-w-[240px]',
                    text: items[i].label,
                  ),
              ],
            ),
            if (i < items.length - 1)
              uiIcon('chevron-right', className: 'w-3.5 h-3.5 text-[var(--text-faint)]'),
          ],
        ],
      ),
    ],
  );
}
