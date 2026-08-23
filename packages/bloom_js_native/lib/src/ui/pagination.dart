import '../framework.dart';
import '../router.dart';
import 'button.dart';
import 'cn.dart';
import 'icons.dart';

const _firstPageMarker = '~';

/// Builds a next page URL appending [nextCursor] to the back-stack query.
String nextPageHref(
    String path, Map<String, String> currentQuery, String nextCursor) {
  final qp = Map<String, String>.from(currentQuery);
  final currentCur =
      (qp['cursor'] ?? '').isEmpty ? _firstPageMarker : qp['cursor']!;
  final backRaw = qp['back'];
  final backList =
      backRaw != null && backRaw.isNotEmpty ? backRaw.split(',') : <String>[];
  backList.add(currentCur);
  qp['cursor'] = nextCursor;
  qp['back'] = backList.join(',');
  return _buildUrlWithQuery(path, qp);
}

/// Builds a previous page URL restoring the cursor from the back-stack query.
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
  final qs = query.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '$path?$qs';
}

/// Reusable cursor-based pagination bar primitive.
BloomNode paginationBar({
  required String currentPath,
  required Map<String, String> currentQuery,
  required int total,
  required int itemCount,
  String? nextCursor,
  int pageSize = 24,
  String extraClassName = '',
}) {
  final backRaw = currentQuery['back'];
  final backList =
      backRaw != null && backRaw.isNotEmpty ? backRaw.split(',') : <String>[];
  final hasPrevious = backList.isNotEmpty;
  final hasNext = nextCursor != null && nextCursor.isNotEmpty;

  final startItem = total == 0 ? 0 : (backList.length * pageSize) + 1;
  final endItem = total == 0 ? 0 : (startItem + itemCount - 1).clamp(0, total);
  final currentPage = backList.length + 1;
  final totalPages = total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;
  final positionText = total == 0
      ? 'No results'
      : 'Showing $startItem–$endItem of $total';
  final pageText = 'Page $currentPage of $totalPages';

  final ghostBtnClasses = buttonClasses(
    variant: ButtonVariant.ghost,
    size: ButtonSize.sm,
    extraClassName:
        'gap-1 px-3 py-1.5 text-xs sm:text-sm border border-[var(--border)]',
  );

  return Div(
    attrs: const {
      'role': 'navigation',
      'aria-label': 'Pagination',
    },
    className: cn([
      'flex flex-col sm:flex-row items-center justify-between gap-4 pt-6 border-t border-[var(--border)]',
      extraClassName,
    ]),
    children: [
      Div(
        className: 'flex items-center gap-2',
        children: [
          if (hasPrevious)
            Link(
              href: prevPageHref(currentPath, currentQuery),
              className: cn([ghostBtnClasses, 'hover:bg-[var(--bg-muted)]']),
              children: [
                uiIcon('chevron-left', className: 'w-4 h-4'),
                Span(text: 'Previous'),
              ],
            )
          else
            El(
              'button',
              attrs: const {
                'type': 'button',
                'disabled': 'true',
                'aria-disabled': 'true',
              },
              className: cn([ghostBtnClasses, 'opacity-50 pointer-events-none']),
              children: [
                uiIcon('chevron-left', className: 'w-4 h-4'),
                Span(text: 'Previous'),
              ],
            ),
          if (hasNext)
            Link(
              href: nextPageHref(currentPath, currentQuery, nextCursor),
              className: cn([ghostBtnClasses, 'hover:bg-[var(--bg-muted)]']),
              children: [
                Span(text: 'Next'),
                uiIcon('chevron-right', className: 'w-4 h-4'),
              ],
            )
          else
            El(
              'button',
              attrs: const {
                'type': 'button',
                'disabled': 'true',
                'aria-disabled': 'true',
              },
              className: cn([ghostBtnClasses, 'opacity-50 pointer-events-none']),
              children: [
                Span(text: 'Next'),
                uiIcon('chevron-right', className: 'w-4 h-4'),
              ],
            ),
        ],
      ),
      Div(
        className:
            'text-xs sm:text-sm text-[var(--text-muted)] flex items-center gap-2 flex-wrap',
        children: [
          Span(text: positionText),
          Span(className: 'text-[var(--text-faint)]', text: '•'),
          Span(text: pageText),
        ],
      ),
    ],
  );
}
