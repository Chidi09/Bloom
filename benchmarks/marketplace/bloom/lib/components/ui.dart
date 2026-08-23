import 'package:bloom_js_native/bloom_js_native.dart';

// HugeIcons — stroke style 1.5px, inline SVG (single icon set, no emoji)
String _hugeIconSvg(String name, {String className = 'w-4 h-4'}) {
  // Minimal handcrafted stroke icons approximating HugeIcons style.
  // Using distinct path data per name to avoid emoji anti-pattern.
  final paths = {
    'package': '<path d="M12 2l9 5v10l-9 5-9-5V7l9-5z"/><path d="M2 7l10 5 10-5"/><path d="M12 12v10"/>',
    'check': '<path d="M5 13l4 4L19 7"/>',
    'alert': '<path d="M12 9v6"/><path d="M12 17h.01"/><path d="M10.3 3.3L2.8 16a2 2 0 001.7 3h15a2 2 0 001.7-3L13.7 3.3a2 2 0 00-3.4 0z"/>',
    'archive': '<rect x="3" y="4" width="18" height="4" rx="1"/><path d="M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8"/><path d="M10 12h4"/>',
    'draft': '<path d="M11 4H6a2 2 0 00-2 2v14a2 2 0 002 2h12a2 2 0 002-2v-9"/><path d="M18 2a2.5 2.5 0 013.5 3.5L11 16l-4 1 1-4 10.5-11z"/>',
    'search': '<circle cx="11" cy="11" r="7"/><path d="M21 21l-3.5-3.5"/>',
    'chevron-right': '<path d="M9 6l6 6-6 6"/>',
    'star': '<path d="M12 3l2.5 5 5.5.8-4 3.9.9 5.3L12 16l-4.9 2.9.9-5.3-4-3.9 5.5-.8L12 3z"/>',
    'shopping': '<path d="M6 6h15l-1.5 9h-13z"/><path d="M6 6L5 2H2"/><circle cx="9" cy="20" r="2"/><circle cx="18" cy="20" r="2"/>',
  };
  final d = paths[name] ?? paths['package']!;
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" class="$className" aria-hidden="true">$d</svg>';
}

BloomNode hugeIcon(String name, {String className = 'w-4 h-4'}) => Raw(_hugeIconSvg(name, className: className));

// Status pill — colour + icon + text (never colour alone)
BloomNode statusPill(String status) {
  String bg, fg, icon;
  switch (status) {
    case 'published':
      bg = 'bg-[#16A34A]/12'; fg = 'text-[#16A34A]'; icon = 'check';
      break;
    case 'draft':
      bg = 'bg-[#D97706]/12'; fg = 'text-[#D97706]'; icon = 'draft';
      break;
    case 'archived':
      bg = 'bg-[#78716C]/15'; fg = 'text-[var(--n-700)]'; icon = 'archive';
      break;
    default:
      bg = 'bg-[var(--bg-muted)]'; fg = 'text-[var(--text-muted)]'; icon = 'alert';
  }
  return Span(
    className: 'inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium border border-[var(--border)] $bg $fg',
    children: [
      hugeIcon(icon, className: 'w-3.5 h-3.5'),
      Text(status),
    ],
  );
}

BloomNode priceText(int cents) {
  final d = (cents / 100).toStringAsFixed(2);
  return Span(className: 'price tabular font-medium', text: '\$$d');
}

BloomNode productCard(dynamic p) {
  // p is Product
  final title = p.title as String;
  final slug = p.slug as String;
  final cents = p.priceCents as int;
  final stock = p.stock as int;
  final status = p.status as String;
  return Link(
    href: '/p/$slug',
    className: 'group flex flex-col rounded-[10px] border border-[var(--border)] bg-[var(--card)] overflow-hidden hover:shadow-md transition-shadow focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)] focus-visible:ring-offset-2',
    children: [
      Div(
        className: 'aspect-[4/3] bg-[var(--bg-muted)] overflow-hidden',
        children: [
          bloomImage(
            src: 'https://picsum.photos/seed/$slug-1/800/800',
            alt: title,
            widths: [400, 800, 1200],
            sizes: '(max-width: 768px) 50vw, 25vw',
            className: 'w-full h-full object-cover group-hover:scale-[1.02] transition-transform duration-200',
          ),
        ],
      ),
      Div(
        className: 'p-3 flex flex-col gap-1.5 flex-1',
        children: [
          P(className: 'text-sm leading-snug line-clamp-2 min-h-[2.75rem]', text: title),
          Div(className: 'flex items-center justify-between gap-2 mt-1', children: [
            priceText(cents),
            Span(
              className: stock == 0 ? 'text-xs text-[var(--danger)]' : stock < 5 ? 'text-xs text-[var(--warning)]' : 'text-xs text-[var(--text-muted)]',
              text: stock == 0 ? 'Out of stock' : stock < 5 ? 'Low stock • $stock left' : 'In stock',
            ),
          ]),
          Div(className: 'mt-1', children: [statusPill(status)]),
        ],
      ),
    ],
  );
}

BloomNode productGrid(List<dynamic> products) {
  return Div(
    className: 'grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4',
    children: products.map((p) => productCard(p)).toList(),
  );
}

BloomNode paginationControls(String? nextCursor, String? prevInfo) {
  // Cursor-based controls: disabled ends, never dead-end link
  // Build next URL preserving query? Expect caller to pass full href
  return Div(
    className: 'flex items-center justify-between gap-4 mt-8',
    children: [
      Div(className: 'text-sm text-[var(--text-muted)]', text: nextCursor == null ? 'End of results' : 'More results available'),
      if (nextCursor != null)
        Link(
          href: '?cursor=${Uri.encodeComponent(nextCursor)}',
          className: 'inline-flex items-center gap-1.5 px-4 py-2 rounded-md bg-[var(--brand-600)] text-white text-sm font-medium hover:bg-[var(--brand-700)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
          children: [Span(text: 'Next'), hugeIcon('chevron-right', className: 'w-4 h-4')],
        )
      else
        Span(className: 'inline-flex items-center px-4 py-2 rounded-md bg-[var(--bg-muted)] text-[var(--text-muted)] text-sm', text: 'No more pages'),
    ],
  );
}

// Table components per design spec: sticky header, borders only, row-hover
BloomNode adminTable({required List<String> headers, required List<BloomNode> rows, BloomNode? empty}) {
  if (rows.isEmpty && empty != null) return empty;
  return Div(
    className: 'overflow-x-auto rounded-[10px] border border-[var(--border)] bg-[var(--card)]',
    children: [
      El('table',
        className: 'w-full text-sm',
        children: [
          El('thead',
            className: 'sticky top-0 bg-[var(--bg-soft)] border-b border-[var(--border)]',
            children: [
              El('tr', children: headers.map((h) => El('th', className: 'text-left font-medium px-4 py-2.5 whitespace-nowrap', text: h)).toList()),
            ],
          ),
          El('tbody', children: rows),
        ],
      ),
    ],
  );
}

BloomNode tableRow(List<BloomNode> cells) {
  return El('tr',
    className: 'border-b border-[var(--border)] last:border-0 hover:bg-[var(--bg-soft)]',
    children: cells.map((c) => El('td', className: 'px-4 py-3 align-middle', children: [c])).toList(),
  );
}
