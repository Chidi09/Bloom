import 'package:bloom_js_native/bloom_js_native.dart';

import '../models/models.dart';
import 'button_variants.dart';
import 'cn.dart';

// HugeIcons — stroke style 1.5px, inline SVG (single icon set, no emoji)
String _hugeIconSvg(String name, {String className = 'w-4 h-4'}) {
  // Real HugeIcons @hugeicons/core-free-icons@4.3.0 path data, extracted from the vendored bundle, not hand-approximated.
  final paths = {
    'package': '<path d="M12 22C11.1818 22 10.4002 21.6698 8.83693 21.0095C4.94564 19.3657 3 18.5438 3 17.1613C3 16.7742 3 10.0645 3 7M12 22C12.8182 22 13.5998 21.6698 15.1631 21.0095C19.0544 19.3657 21 18.5438 21 17.1613V7M12 22L12 11.3548" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M8.32592 9.69138L5.40472 8.27785C3.80157 7.5021 3 7.11423 3 6.5C3 5.88577 3.80157 5.4979 5.40472 4.72215L8.32592 3.30862C10.1288 2.43621 11.0303 2 12 2C12.9697 2 13.8712 2.4362 15.6741 3.30862L18.5953 4.72215C20.1984 5.4979 21 5.88577 21 6.5C21 7.11423 20.1984 7.5021 18.5953 8.27785L15.6741 9.69138C13.8712 10.5638 12.9697 11 12 11C11.0303 11 10.1288 10.5638 8.32592 9.69138Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M6 12L8 13" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M17 4L7 9" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
    'check': '<path d="M5 14L8.5 17.5L19 6.5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
    'alert': '<path d="M13.9248 21H10.0752C5.44476 21 3.12955 21 2.27636 19.4939C1.42317 17.9879 2.60736 15.9914 4.97574 11.9985L6.90057 8.75333C9.17559 4.91778 10.3131 3 12 3C13.6869 3 14.8244 4.91777 17.0994 8.75332L19.0243 11.9985C21.3926 15.9914 22.5768 17.9879 21.7236 19.4939C20.8704 21 18.5552 21 13.9248 21Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M12 9V13" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M12.125 16.75H12M12.25 16.75C12.25 16.8881 12.1381 17 12 17C11.8619 17 11.75 16.8881 11.75 16.75C11.75 16.6119 11.8619 16.5 12 16.5C12.1381 16.5 12.25 16.6119 12.25 16.75Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
    'archive': '<path d="M10.0001 17V7C10.0001 5.11438 10.0001 4.17157 9.41427 3.58579C8.82849 3 7.88568 3 6.00005 3C4.11444 3 3.17163 3 2.58584 3.58578C2.00006 4.17157 2.00005 5.11437 2.00004 6.99998L2 17C1.99999 18.8856 1.99999 19.8284 2.58577 20.4142C3.17156 21 4.11438 21 6.00003 21C7.88567 21 8.82849 21 9.41427 20.4142C10.0001 19.8284 10.0001 18.8856 10.0001 17Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M21.4558 15.7091L19.0473 7.19224C18.572 5.51165 18.3343 4.67135 17.6838 4.2617C17.6312 4.22861 17.5772 4.19796 17.5218 4.16986C16.8358 3.82199 15.9877 4.04691 14.2916 4.49674C12.5529 4.95783 11.6836 5.18838 11.2632 5.84738C11.2293 5.90053 11.198 5.95524 11.1693 6.01134C10.8134 6.70684 11.057 7.5682 11.5442 9.2909L13.9527 17.8078C14.428 19.4884 14.6657 20.3287 15.3162 20.7383C15.3688 20.7714 15.4228 20.802 15.4782 20.8301C16.1642 21.178 17.0123 20.9531 18.7084 20.5033C20.4471 20.0422 21.3164 19.8116 21.7368 19.1526C21.7707 19.0995 21.802 19.0448 21.8307 18.9887C22.1866 18.2932 21.943 17.4318 21.4558 15.7091Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M2 7H10" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M12 9.00019L19 7" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M6.125 17H6M6.25 17C6.25 17.1381 6.13807 17.25 6 17.25C5.86193 17.25 5.75 17.1381 5.75 17C5.75 16.8619 5.86193 16.75 6 16.75C6.13807 16.75 6.25 16.8619 6.25 17Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M17.7307 16.75H17.6057M17.8557 16.75C17.8557 16.8881 17.7437 17 17.6057 17C17.4676 17 17.3557 16.8881 17.3557 16.75C17.3557 16.6119 17.4676 16.5 17.6057 16.5C17.7437 16.5 17.8557 16.6119 17.8557 16.75Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
    'draft': '<path d="M16.4249 4.60509L17.4149 3.6151C18.2351 2.79497 19.5648 2.79497 20.3849 3.6151C21.205 4.43524 21.205 5.76493 20.3849 6.58507L19.3949 7.57506M16.4249 4.60509L9.76558 11.2644C9.25807 11.772 8.89804 12.4078 8.72397 13.1041L8 16L10.8959 15.276C11.5922 15.102 12.228 14.7419 12.7356 14.2344L19.3949 7.57506M16.4249 4.60509L19.3949 7.57506" stroke="currentColor" stroke-linejoin="round" stroke-width="1.5"/><path d="M18.9999 13.5C18.9999 16.7875 18.9999 18.4312 18.092 19.5376C17.9258 19.7401 17.7401 19.9258 17.5375 20.092C16.4312 21 14.7874 21 11.4999 21H11C7.22876 21 5.34316 21 4.17159 19.8284C3.00003 18.6569 3 16.7712 3 13V12.5C3 9.21252 3 7.56879 3.90794 6.46244C4.07417 6.2599 4.2599 6.07417 4.46244 5.90794C5.56879 5 7.21252 5 10.5 5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
    'search': '<path d="M17 17L21 21" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M19 11C19 6.58172 15.4183 3 11 3C6.58172 3 3 6.58172 3 11C3 15.4183 6.58172 19 11 19C15.4183 19 19 15.4183 19 11Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
    'chevron-left': '<path d="M15 18C15 18 9.00005 13.5811 9.00005 12C9.00005 10.4188 15 6 15 6" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
    'chevron-right': '<path d="M9.00005 18C9.00005 18 15 13.5811 15 12C15 10.4188 9 6 9 6" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
    'star': '<path d="M13.7276 3.44418L15.4874 6.99288C15.7274 7.48687 16.3673 7.9607 16.9073 8.05143L20.0969 8.58575C22.1367 8.92853 22.6167 10.4206 21.1468 11.8925L18.6671 14.3927C18.2471 14.8161 18.0172 15.6327 18.1471 16.2175L18.8571 19.3125C19.417 21.7623 18.1271 22.71 15.9774 21.4296L12.9877 19.6452C12.4478 19.3226 11.5579 19.3226 11.0079 19.6452L8.01827 21.4296C5.8785 22.71 4.57865 21.7522 5.13859 19.3125L5.84851 16.2175C5.97849 15.6327 5.74852 14.8161 5.32856 14.3927L2.84884 11.8925C1.389 10.4206 1.85895 8.92853 3.89872 8.58575L7.08837 8.05143C7.61831 7.9607 8.25824 7.48687 8.49821 6.99288L10.258 3.44418C11.2179 1.51861 12.7777 1.51861 13.7276 3.44418Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
    'shopping': '<path d="M10.5 20.25C10.5 20.6642 10.1642 21 9.75 21C9.33579 21 9 20.6642 9 20.25C9 19.8358 9.33579 19.5 9.75 19.5C10.1642 19.5 10.5 19.8358 10.5 20.25Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M19 20.25C19 20.6642 18.6642 21 18.25 21C17.8358 21 17.5 20.6642 17.5 20.25C17.5 19.8358 17.8358 19.5 18.25 19.5C18.6642 19.5 19 19.8358 19 20.25Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M2 3H2.20664C3.53124 3 4.19354 3 4.6255 3.40221C5.05746 3.80441 5.10464 4.46503 5.19902 5.78626L5.45035 9.30496C5.5924 11.2936 5.66342 12.2879 5.96476 13.0961C6.62531 14.8677 8.08229 16.2244 9.89648 16.757C10.7241 17 11.7267 17 13.7317 17C15.8373 17 16.89 17 17.7417 16.7416C19.6593 16.1599 21.1599 14.6593 21.7416 12.7417C22 11.89 22 10.8433 22 8.75C22 8.05222 22 7.70333 21.9139 7.41943C21.72 6.78023 21.2198 6.28002 20.5806 6.08612C20.2967 6 19.9478 6 19.25 6H5.5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M16 10V13M11 10V13" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
    'x': '<path d="M18 6L6 18M6 6L18 18" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
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
      bg = 'bg-[#78716C]/15'; fg = 'text-[var(--n-400)]'; icon = 'archive';
      break;
    default:
      bg = 'bg-[var(--bg-muted)]'; fg = 'text-[var(--text-muted)]'; icon = 'alert';
  }
  return Span(
    // Resolved through cn() (clsx + tailwind-merge) rather than string
    // interpolation, so a caller could later pass an override class without
    // producing two conflicting `bg-*` utilities in the final class list.
    className: cn([
      'inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium border border-[var(--border)]',
      bg,
      fg,
    ]),
    children: [
      hugeIcon(icon, className: 'w-3.5 h-3.5'),
      Text(status),
    ],
  );
}

/// Button per the design spec's component contract: primary / secondary /
/// ghost / destructive, variant classes resolved via `cva`.
BloomNode button({
  required String text,
  ButtonVariant variant = ButtonVariant.primary,
  String? href,
  String extraClassName = '',
  Map<String, String> attrs = const {},
  BloomEventHandler? onClick,
}) {
  final className = cn([buttonClasses(variant), extraClassName]);
  if (href != null) {
    return Link(href: href, className: className, children: [Text(text)], onClick: onClick);
  }
  return El('button', attrs: attrs, className: className, children: [Text(text)], onClick: onClick);
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
  return Link(
    href: '/p/$slug',
    className: 'group flex flex-col rounded-[10px] border border-[var(--border)] bg-[var(--card)] overflow-hidden shadow-[var(--shadow-card)] hover:shadow-md transition-shadow focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)] focus-visible:ring-offset-2',
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
          P(className: 'text-sm leading-snug line-clamp-2 min-h-[2.75rem] text-[var(--text)] group-hover:text-[var(--brand-600)] transition-colors', text: title),
          Div(className: 'flex items-center justify-between gap-2 mt-1', children: [
            priceText(cents),
            Span(
              className: cn([
                'text-xs',
                stock == 0
                    ? 'text-[var(--danger)]'
                    : stock < 5
                        ? 'text-[var(--warning)]'
                        : 'text-[var(--text-muted)]',
              ]),
              text: stock == 0 ? 'Out of stock' : stock < 5 ? 'Low stock • $stock left' : 'In stock',
            ),
          ]),
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

/// Skeleton loader components mimicking component shapes with pulse animation
BloomNode skeletonCard() {
  return Div(
    className: 'flex flex-col rounded-[10px] border border-[var(--border)] bg-[var(--card)] overflow-hidden shadow-[var(--shadow-card)] animate-pulse',
    children: [
      Div(className: 'aspect-[4/3] bg-[var(--bg-muted)]'),
      Div(
        className: 'p-3 flex flex-col gap-2 flex-1',
        children: [
          Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-3/4'),
          Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-1/2'),
          Div(className: 'flex items-center justify-between mt-auto pt-2', children: [
            Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-16'),
            Div(className: 'h-3 bg-[var(--bg-muted)] rounded w-12'),
          ]),
        ],
      ),
    ],
  );
}

BloomNode skeletonTable([int rows = 6]) {
  return Div(
    className: 'overflow-x-auto rounded-[10px] border border-[var(--border)] bg-[var(--card)] shadow-[var(--shadow-card)] animate-pulse',
    children: [
      El('table',
        className: 'w-full text-sm',
        children: [
          El('thead',
            className: 'bg-[var(--bg-soft)] border-b border-[var(--border)]',
            children: [
              El('tr', children: [
                El('th', className: 'text-left font-medium px-4 py-2.5', children: [Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-20')]),
                El('th', className: 'text-right font-medium px-4 py-2.5', children: [Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-12 ml-auto')]),
                El('th', className: 'text-right font-medium px-4 py-2.5', children: [Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-12 ml-auto')]),
                El('th', className: 'text-left font-medium px-4 py-2.5', children: [Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-16')]),
                El('th', className: 'px-4 py-2.5', children: [Div(className: 'h-4 w-8')]),
              ]),
            ],
          ),
          El('tbody', children: List.generate(rows, (_) => El('tr',
            className: 'border-b border-[var(--border)] last:border-0',
            children: [
              El('td', className: 'px-4 py-3 align-middle', children: [
                Div(className: 'flex items-center gap-3', children: [
                  Div(className: 'w-9 h-9 rounded-md bg-[var(--bg-muted)] shrink-0'),
                  Div(className: 'flex flex-col gap-1.5 flex-1', children: [
                    Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-40'),
                    Div(className: 'h-3 bg-[var(--bg-muted)] rounded w-24'),
                  ]),
                ]),
              ]),
              El('td', className: 'px-4 py-3 align-middle text-right', children: [Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-12 ml-auto')]),
              El('td', className: 'px-4 py-3 align-middle text-right', children: [Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-8 ml-auto')]),
              El('td', className: 'px-4 py-3 align-middle', children: [Div(className: 'h-5 bg-[var(--bg-muted)] rounded-full w-20')]),
              El('td', className: 'px-4 py-3 align-middle text-right', children: [Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-8 ml-auto')]),
            ],
          ))),
        ],
      ),
    ],
  );
}

BloomNode skeletonDetail() {
  return Div(
    className: 'animate-pulse flex flex-col gap-6',
    children: [
      Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-48 mb-2'),
      Div(className: 'grid lg:grid-cols-2 gap-8', children: [
        Div(className: 'flex flex-col gap-3', children: [
          Div(className: 'w-full aspect-square max-h-[420px] md:max-h-[480px] rounded-[10px] bg-[var(--bg-muted)] border border-[var(--border)]'),
          Div(className: 'grid grid-cols-3 gap-2', children: [
            Div(className: 'aspect-square rounded-md bg-[var(--bg-muted)]'),
            Div(className: 'aspect-square rounded-md bg-[var(--bg-muted)]'),
            Div(className: 'aspect-square rounded-md bg-[var(--bg-muted)]'),
          ]),
        ]),
        Div(className: 'flex flex-col gap-4', children: [
          Div(className: 'h-3 bg-[var(--bg-muted)] rounded w-20'),
          Div(className: 'h-8 bg-[var(--bg-muted)] rounded w-3/4'),
          Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-28'),
          Div(className: 'h-8 bg-[var(--bg-muted)] rounded w-24 mt-2'),
          Div(className: 'flex flex-col gap-2 mt-2', children: [
            Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-full'),
            Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-full'),
            Div(className: 'h-4 bg-[var(--bg-muted)] rounded w-2/3'),
          ]),
          Div(className: 'flex gap-3 mt-4', children: [
            Div(className: 'h-11 bg-[var(--bg-muted)] rounded-md w-36'),
            Div(className: 'h-11 bg-[var(--bg-muted)] rounded-md w-40'),
          ]),
        ]),
      ]),
    ],
  );
}

// Marks "page 1" (no cursor) in the back-stack. Never emitted by the
// base64url cursor encoder, so it can't collide with a real cursor value —
// unlike an empty string, which is indistinguishable from "no entry" once
// the stack is comma-joined and round-tripped through a query string.
const _firstPageMarker = '~';

String nextPageHref(String path, Map<String, String> currentQuery, String nextCursor) {
  final qp = Map<String, String>.from(currentQuery);
  final currentCur = (qp['cursor'] ?? '').isEmpty ? _firstPageMarker : qp['cursor']!;
  final backRaw = qp['back'];
  final backList = backRaw != null && backRaw.isNotEmpty ? backRaw.split(',') : <String>[];
  backList.add(currentCur);
  qp['cursor'] = nextCursor;
  qp['back'] = backList.join(',');
  return _buildUrlWithQuery(path, qp);
}

String prevPageHref(String path, Map<String, String> currentQuery) {
  final qp = Map<String, String>.from(currentQuery);
  final backRaw = qp['back'];
  if (backRaw == null || backRaw.isEmpty) return _buildUrlWithQuery(path, qp);
  final backList = backRaw.split(',');
  final prevCur = backList.removeLast();
  if (prevCur == _firstPageMarker) {
    qp.remove('cursor');
  } else {
    qp['cursor'] = prevCur;
  }
  if (backList.isEmpty) {
    qp.remove('back');
  } else {
    qp['back'] = backList.join(',');
  }
  return _buildUrlWithQuery(path, qp);
}

String _buildUrlWithQuery(String path, Map<String, String> query) {
  if (query.isEmpty) return path;
  final qs = query.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
  return '$path?$qs';
}

BloomNode paginationBar({
  required String currentPath,
  required Map<String, String> currentQuery,
  required int total,
  required int itemCount,
  String? nextCursor,
  int pageSize = 24,
}) {
  final backRaw = currentQuery['back'];
  final backList = backRaw != null && backRaw.isNotEmpty ? backRaw.split(',') : <String>[];
  final hasPrevious = backList.isNotEmpty;
  final hasNext = nextCursor != null && nextCursor.isNotEmpty;

  final startItem = total == 0 ? 0 : (backList.length * pageSize) + 1;
  final endItem = total == 0 ? 0 : (startItem + itemCount - 1).clamp(0, total);
  final currentPage = backList.length + 1;
  final totalPages = total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;
  final positionText = total == 0
      ? 'No results'
      : 'Showing ${formatNumber(startItem)}–${formatNumber(endItem)} of ${formatNumber(total)}';
  final pageText = 'Page $currentPage of $totalPages';

  return Div(
    attrs: aria(role: AriaRole.navigation, label: 'Pagination'),
    className: 'flex flex-col sm:flex-row items-center justify-between gap-4 mt-8 pt-6 border-t border-[var(--border)]',
    children: [
      Div(
        className: 'flex items-center gap-2',
        children: [
          if (hasPrevious)
            Link(
              href: prevPageHref(currentPath, currentQuery),
              className: cn([buttonClasses(ButtonVariant.ghost), 'gap-1 px-3 py-1.5 text-sm border border-[var(--border)] hover:bg-[var(--bg-muted)]']),
              children: [
                hugeIcon('chevron-left', className: 'w-4 h-4'),
                Span(text: 'Previous'),
              ],
            )
          else
            El('button',
              attrs: {'type': 'button', 'disabled': 'true', 'aria-disabled': 'true'},
              className: cn([buttonClasses(ButtonVariant.ghost), 'gap-1 px-3 py-1.5 text-sm border border-[var(--border)] opacity-50 pointer-events-none']),
              children: [
                hugeIcon('chevron-left', className: 'w-4 h-4'),
                Span(text: 'Previous'),
              ],
            ),
          if (hasNext)
            Link(
              href: nextPageHref(currentPath, currentQuery, nextCursor),
              className: cn([buttonClasses(ButtonVariant.ghost), 'gap-1 px-3 py-1.5 text-sm border border-[var(--border)] hover:bg-[var(--bg-muted)]']),
              children: [
                Span(text: 'Next'),
                hugeIcon('chevron-right', className: 'w-4 h-4'),
              ],
            )
          else
            El('button',
              attrs: {'type': 'button', 'disabled': 'true', 'aria-disabled': 'true'},
              className: cn([buttonClasses(ButtonVariant.ghost), 'gap-1 px-3 py-1.5 text-sm border border-[var(--border)] opacity-50 pointer-events-none']),
              children: [
                Span(text: 'Next'),
                hugeIcon('chevron-right', className: 'w-4 h-4'),
              ],
            ),
        ],
      ),
      Div(
        className: 'text-sm text-[var(--text-muted)] flex items-center gap-2 flex-wrap',
        children: [
          Span(text: positionText),
          Span(className: 'text-[var(--text-faint)]', text: '•'),
          Span(text: pageText),
          if (!hasNext && total > 0)
            Span(className: 'text-xs text-[var(--text-faint)]', text: '• End of results'),
        ],
      ),
    ],
  );
}

// Table components per design spec: sticky header, borders only, row-hover
BloomNode adminTable({required List<String> headers, required List<BloomNode> rows, BloomNode? empty}) {
  if (rows.isEmpty && empty != null) return empty;
  return Div(
    className: 'overflow-x-auto rounded-[10px] border border-[var(--border)] bg-[var(--card)] shadow-[var(--shadow-card)]',
    children: [
      El('table',
        className: 'w-full text-sm',
        children: [
          El('thead',
            className: 'sticky top-0 bg-[var(--bg-soft)] border-b border-[var(--border)]',
            children: [
              El('tr', children: headers.map((h) {
                final isRight = h == 'Price' || h == 'Stock';
                final align = isRight ? 'text-right' : 'text-left';
                return El('th', className: '$align font-medium px-4 py-2.5 whitespace-nowrap', text: h);
              }).toList()),
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

/// Interactive product gallery with reactive active-image switching
BloomNode productGallery(List<ProductImage> images) {
  if (images.isEmpty) {
    return Div(
      className: 'aspect-square rounded-[10px] bg-[var(--bg-muted)] grid place-items-center text-[var(--text-muted)]',
      text: 'No image',
    );
  }

  final activeIndex = signal<int>(0);

  return Div(
    className: 'flex flex-col gap-3',
    children: [
      Live(() {
        final idx = activeIndex.value.clamp(0, images.length - 1);
        final current = images[idx];
        return bloomImage(
          src: current.url,
          alt: current.alt,
          widths: [600, 800, 1200],
          sizes: '(max-width:1024px) 100vw, 50vw',
          className: 'w-full aspect-square max-h-[420px] md:max-h-[480px] object-cover rounded-[10px] border border-[var(--border)] bg-[var(--bg-muted)]',
          priority: true,
        );
      }),
      if (images.length > 1)
        Live(() {
          final cur = activeIndex.value;
          return Div(
            className: 'grid grid-cols-3 gap-2',
            children: List.generate(images.length, (i) {
              final im = images[i];
              final isActive = i == cur;
              return El('button',
                attrs: {
                  'type': 'button',
                  'aria-label': 'View image ${i + 1}',
                  if (isActive) 'aria-current': 'true',
                },
                className: cn([
                  'aspect-square rounded-md overflow-hidden border border-[var(--border)] focus-visible:outline-none cursor-pointer',
                  isActive
                      ? 'ring-2 ring-[var(--brand-600)] ring-offset-2 ring-offset-[var(--bg)]'
                      : 'opacity-60 hover:opacity-100 transition-opacity',
                ]),
                onClick: (_) {
                  activeIndex.value = i;
                },
                children: [
                  bloomImage(
                    src: im.url,
                    alt: im.alt,
                    widths: [300, 600],
                    sizes: '200px',
                    className: 'w-full h-full object-cover',
                  ),
                ],
              );
            }),
          );
        }),
    ],
  );
}

/// Storefront filter bar with category pills, in-stock toggle, and active filter chips
BloomNode filterBar({
  required String currentPath,
  required Map<String, String> currentQuery,
  required List<Category> categories,
  String? currentCategorySlug,
}) {
  final isInStock = currentQuery['in_stock'] == 'true';
  final isAllActive = currentCategorySlug == null || currentCategorySlug.isEmpty;

  // In-stock toggle href
  final inStockQp = Map<String, String>.from(currentQuery)..remove('cursor')..remove('back');
  if (isInStock) {
    inStockQp.remove('in_stock');
  } else {
    inStockQp['in_stock'] = 'true';
  }
  final inStockHref = _buildUrlWithQuery(currentPath, inStockQp);

  // Active category lookup
  Category? activeCat;
  if (currentCategorySlug != null && currentCategorySlug.isNotEmpty) {
    for (final c in categories) {
      if (c.slug == currentCategorySlug) {
        activeCat = c;
        break;
      }
    }
  }

  final hasActiveFilters = !isAllActive || isInStock;

  // Category navigation href
  String categoryHref(String? slug) {
    final qp = <String, String>{};
    if (currentQuery.containsKey('sort')) qp['sort'] = currentQuery['sort']!;
    if (currentQuery.containsKey('in_stock')) qp['in_stock'] = currentQuery['in_stock']!;
    if (slug == null || slug.isEmpty) {
      return _buildUrlWithQuery('/', qp);
    }
    return _buildUrlWithQuery('/c/$slug', qp);
  }

  // Dismiss category filter href: goes back to '/' keeping in_stock & sort
  final dismissCategoryHref = categoryHref(null);

  // Dismiss in-stock filter href: currentPath with in_stock removed
  final dismissInStockQp = Map<String, String>.from(currentQuery)
    ..remove('in_stock')
    ..remove('cursor')
    ..remove('back');
  final dismissInStockHref = _buildUrlWithQuery(currentPath, dismissInStockQp);

  return Div(
    className: 'flex flex-col gap-3 mb-6',
    children: [
      Div(
        className: 'flex flex-wrap items-center gap-2 text-sm',
        children: [
          Span(className: 'text-[var(--text-muted)] mr-1', text: 'Category:'),
          Link(
            href: categoryHref(null),
            attrs: isAllActive ? {'aria-current': 'page'} : const {},
            className: isAllActive
                ? 'px-2.5 py-1 rounded-md bg-[var(--brand-600)] text-white font-medium text-xs sm:text-sm'
                : 'px-2.5 py-1 rounded-md border border-[var(--border)] hover:bg-[var(--bg-muted)] text-xs sm:text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
            text: 'All',
          ),
          ...categories.map((cat) {
            final isActive = currentCategorySlug == cat.slug;
            return Link(
              href: categoryHref(cat.slug),
              attrs: isActive ? {'aria-current': 'page'} : const {},
              className: isActive
                  ? 'px-2.5 py-1 rounded-md bg-[var(--brand-600)] text-white font-medium text-xs sm:text-sm'
                  : 'px-2.5 py-1 rounded-md border border-[var(--border)] hover:bg-[var(--bg-muted)] text-xs sm:text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
              text: cat.name,
            );
          }),
          Span(className: 'text-[var(--text-faint)] mx-1 hidden sm:inline', text: '|'),
          Link(
            href: inStockHref,
            attrs: isInStock ? {'aria-pressed': 'true'} : {'aria-pressed': 'false'},
            className: isInStock
                ? 'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-[var(--brand-600)] text-white font-medium text-xs sm:text-sm'
                : 'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md border border-[var(--border)] hover:bg-[var(--bg-muted)] text-xs sm:text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
            children: [
              if (isInStock) hugeIcon('check', className: 'w-3.5 h-3.5')
              else Span(className: 'w-2 h-2 rounded-full bg-[var(--text-muted)]'),
              Span(text: 'In stock only'),
            ],
          ),
        ],
      ),
      if (hasActiveFilters)
        Div(
          className: 'flex flex-wrap items-center gap-2 text-xs pt-1',
          children: [
            Span(className: 'text-[var(--text-muted)] font-medium', text: 'Active filters:'),
            if (!isAllActive)
              Link(
                href: dismissCategoryHref,
                className: 'inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-[var(--bg-muted)] border border-[var(--border)] text-[var(--text)] hover:bg-[var(--border)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
                children: [
                  Span(text: activeCat?.name ?? currentCategorySlug),
                  hugeIcon('x', className: 'w-3 h-3 text-[var(--text-muted)]'),
                ],
              ),
            if (isInStock)
              Link(
                href: dismissInStockHref,
                className: 'inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-[var(--bg-muted)] border border-[var(--border)] text-[var(--text)] hover:bg-[var(--border)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
                children: [
                  Span(text: 'In stock only'),
                  hugeIcon('x', className: 'w-3 h-3 text-[var(--text-muted)]'),
                ],
              ),
            Link(
              href: '/',
              className: 'text-[var(--text-muted)] hover:text-[var(--danger)] hover:underline ml-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)] rounded px-1',
              text: 'Clear all',
            ),
          ],
        ),
    ],
  );
}
