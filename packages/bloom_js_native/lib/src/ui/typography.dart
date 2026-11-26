import '../framework.dart';
import 'cn.dart';

/// Display heading level 1 (`<h1>`).
BloomNode uiH1(String text, {String extraClassName = ''}) => H1(
      className: cn([
        'scroll-m-20 text-4xl font-extrabold tracking-tight text-[var(--text)]',
        extraClassName,
      ]),
      text: text,
    );

/// Section heading level 2 (`<h2>`).
BloomNode uiH2(String text, {String extraClassName = ''}) => H2(
      className: cn([
        'scroll-m-20 border-b border-[var(--border)] pb-2 text-3xl font-semibold tracking-tight text-[var(--text)]',
        extraClassName,
      ]),
      text: text,
    );

/// Subsection heading level 3 (`<h3>`).
BloomNode uiH3(String text, {String extraClassName = ''}) => H3(
      className: cn([
        'scroll-m-20 text-2xl font-semibold tracking-tight text-[var(--text)]',
        extraClassName,
      ]),
      text: text,
    );

/// Minor heading level 4 (`<h4>`).
BloomNode uiH4(String text, {String extraClassName = ''}) => H4(
      className: cn([
        'scroll-m-20 text-xl font-semibold tracking-tight text-[var(--text)]',
        extraClassName,
      ]),
      text: text,
    );

/// Standard body paragraph (`<p>`).
BloomNode uiP(String text, {String extraClassName = ''}) => P(
      className: cn(['leading-7 text-[var(--text)]', extraClassName]),
      text: text,
    );

/// Emphasized introductory lead paragraph.
BloomNode uiLead(String text, {String extraClassName = ''}) => P(
      className: cn(['text-xl text-[var(--text-muted)]', extraClassName]),
      text: text,
    );

/// Secondary muted text span.
BloomNode uiMuted(String text, {String extraClassName = ''}) => P(
      className: cn(['text-sm text-[var(--text-muted)]', extraClassName]),
      text: text,
    );

/// Styled blockquote (`<blockquote>`).
BloomNode uiBlockquote(String text, {String extraClassName = ''}) => Blockquote(
      className: cn([
        'mt-4 border-l-2 border-[var(--border)] pl-4 italic text-[var(--text-muted)]',
        extraClassName,
      ]),
      text: text,
    );

/// Inline monospace code snippet (`<code>`).
BloomNode uiInlineCode(String text, {String extraClassName = ''}) => Code(
      className: cn([
        'relative rounded-[var(--radius-sm)] bg-[var(--bg-muted)] px-1.5 py-0.5 font-mono text-sm font-semibold text-[var(--text)]',
        extraClassName,
      ]),
      text: text,
    );
