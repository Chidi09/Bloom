import '../framework.dart';
import 'cn.dart';

/// Top-level application layout shell with optional header, sidebar, and footer.
BloomNode appShell({
  BloomNode? header,
  BloomNode? sidebar,
  required BloomNode body,
  BloomNode? footer,
  String extraClassName = '',
}) {
  return Div(
    className: cn([
      'min-h-screen flex flex-col bg-[var(--bg)] text-[var(--text)]',
      extraClassName,
    ]),
    children: [
      if (header != null)
        Header(
          className:
              'shrink-0 border-b border-[var(--border)] bg-[var(--bg)]',
          children: [header],
        ),
      Div(
        className: 'flex-1 flex min-h-0',
        children: [
          if (sidebar != null) sidebar,
          Main(
            className: 'flex-1 min-w-0 p-6 overflow-y-auto',
            children: [body],
          ),
        ],
      ),
      if (footer != null)
        Footer(
          className:
              'shrink-0 border-t border-[var(--border)] bg-[var(--bg-soft)]',
          children: [footer],
        ),
    ],
  );
}

/// Dashboard layout shell pairing a persistent [sidebar] with an optional [topBar]
/// and main [content] region.
BloomNode dashboardShell({
  required BloomNode sidebar,
  BloomNode? topBar,
  required BloomNode content,
  String extraClassName = '',
}) {
  return Div(
    className: cn([
      'min-h-screen flex bg-[var(--bg)] text-[var(--text)]',
      extraClassName,
    ]),
    children: [
      sidebar,
      Div(
        className: 'flex-1 flex flex-col min-w-0',
        children: [
          if (topBar != null)
            Header(
              className:
                  'shrink-0 border-b border-[var(--border)] px-6 py-3 bg-[var(--bg)]',
              children: [topBar],
            ),
          Main(
            className: 'flex-1 p-6 overflow-y-auto',
            children: [content],
          ),
        ],
      ),
    ],
  );
}
