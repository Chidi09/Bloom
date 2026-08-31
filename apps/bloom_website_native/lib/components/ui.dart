import 'package:bloom_js_native/bloom_js_native.dart';
import 'huge_icons.dart';

/// Semantic Button component for Bloom marketing pages
BloomNode siteButton({
  required String label,
  ButtonVariant variant = ButtonVariant.primary,
  ButtonSize size = ButtonSize.md,
  String? href,
  BloomEventHandler? onClick,
  String? prefixIcon,
  String? suffixIcon,
  String? className,
  Map<String, String>? attrs,
}) {
  final baseClass =
      'inline-flex items-center justify-center font-medium transition-all duration-150 '
      'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 '
      'disabled:opacity-50 disabled:pointer-events-none cursor-pointer select-none';

  final variantClass = switch (variant) {
    ButtonVariant.primary =>
      'bg-[#6366F1] hover:bg-[#4F46E5] text-white shadow-md shadow-indigo-600/20 active:scale-[0.98]',
    ButtonVariant.secondary =>
      'bg-[#14141A] hover:bg-[#1E1E24] text-zinc-200 border border-[#27272A] active:scale-[0.98]',
    ButtonVariant.outline =>
      'bg-transparent hover:bg-[#14141A] text-zinc-300 border border-[#27272A] hover:border-zinc-500 active:scale-[0.98]',
    ButtonVariant.ghost =>
      'bg-transparent hover:bg-[#14141A] text-zinc-400 hover:text-white',
    ButtonVariant.destructive =>
      'bg-red-600 hover:bg-red-500 text-white shadow-md shadow-red-600/20 active:scale-[0.98]',
    _ =>
      'bg-[#6366F1] hover:bg-[#4F46E5] text-white shadow-md shadow-indigo-600/20',
  };

  final sizeClass = switch (size) {
    ButtonSize.sm => 'text-xs px-3 py-1.5 rounded-lg gap-1.5',
    ButtonSize.md => 'text-sm px-4 py-2.5 rounded-xl gap-2',
    ButtonSize.lg => 'text-base px-6 py-3.5 rounded-xl gap-2.5 font-semibold',
    _ => 'text-sm px-4 py-2.5 rounded-xl gap-2',
  };

  final classes = cn([baseClass, variantClass, sizeClass, className]);
  final children = <BloomNode>[
    if (prefixIcon != null)
      hugeIcon(
        prefixIcon,
        className: size == ButtonSize.sm ? 'w-3.5 h-3.5' : 'w-4 h-4',
      ),
    Text(label),
    if (suffixIcon != null)
      hugeIcon(
        suffixIcon,
        className: size == ButtonSize.sm ? 'w-3.5 h-3.5' : 'w-4 h-4',
      ),
  ];

  if (href != null) {
    return A(href: href, className: classes, attrs: attrs, children: children);
  }

  return Button(
    className: classes,
    onClick: onClick,
    attrs: attrs,
    children: children,
  );
}

/// Semantic status badge
BloomNode siteBadge({
  required String label,
  String variant = 'default',
  String? icon,
  String? className,
}) {
  final (bg, fg, border) = switch (variant) {
    'brand' => ('bg-indigo-500/10', 'text-indigo-400', 'border-indigo-500/20'),
    'success' => (
      'bg-emerald-500/10',
      'text-emerald-400',
      'border-emerald-500/20',
    ),
    'warning' => ('bg-amber-500/10', 'text-amber-400', 'border-amber-500/20'),
    'cyan' => ('bg-cyan-500/10', 'text-cyan-400', 'border-cyan-500/20'),
    'destructive' => ('bg-red-500/10', 'text-red-400', 'border-red-500/20'),
    _ => ('bg-[#18181B]', 'text-zinc-300', 'border-[#27272A]'),
  };

  return Span(
    className: cn([
      'inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium border font-mono',
      bg,
      fg,
      border,
      className,
    ]),
    children: [
      if (icon != null) hugeIcon(icon, className: 'w-3 h-3'),
      Text(label),
    ],
  );
}

/// Elevated surface card container
BloomNode siteCard({
  required List<BloomNode> children,
  String? className,
  String? id,
  bool glow = false,
}) {
  return Div(
    attrs: id != null ? {'id': id} : null,
    className: cn([
      'rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 transition-all duration-200',
      glow
          ? 'hover:border-indigo-500/40 hover:shadow-2xl hover:shadow-indigo-500/10'
          : 'hover:border-[#27272A]',
      className,
    ]),
    children: children,
  );
}

/// Terminal / Code block with title bar and copy trigger
BloomNode siteCodeBlock({
  required String code,
  String? filename,
  String language = 'bash',
  String? className,
}) {
  return Div(
    className: cn([
      'rounded-xl bg-[#0C0C0E] border border-[#1E1E24] overflow-hidden font-mono text-xs shadow-xl',
      className,
    ]),
    children: [
      // Title Bar
      Div(
        className:
            'flex items-center justify-between px-4 py-2.5 '
            'bg-[#14141A] border-b border-[#1E1E24] select-none',
        children: [
          Div(
            className: 'flex items-center gap-2',
            children: [
              Div(className: 'w-2.5 h-2.5 rounded-full bg-[#27272A]'),
              Div(className: 'w-2.5 h-2.5 rounded-full bg-[#27272A]'),
              Div(className: 'w-2.5 h-2.5 rounded-full bg-[#27272A]'),
              if (filename != null)
                Span(
                  className: 'ml-2 text-zinc-400 font-medium',
                  text: filename,
                ),
            ],
          ),
          Div(
            className: 'flex items-center gap-2',
            children: [
              Span(
                className: 'text-[10px] text-zinc-500 uppercase tracking-wider',
                text: language,
              ),
            ],
          ),
        ],
      ),
      // Code Content
      Div(
        className:
            'p-4 overflow-x-auto text-zinc-300 leading-relaxed font-mono',
        children: [
          Pre(
            className: 'm-0',
            children: [Code(text: code)],
          ),
        ],
      ),
    ],
  );
}

/// Section title and description header
BloomNode siteSectionHeader({
  required String eyebrow,
  required String title,
  required String description,
  String? eyebrowIcon,
  bool centered = true,
  String? className,
}) {
  return Div(
    className: cn([
      centered ? 'text-center max-w-3xl mx-auto mb-16' : 'max-w-3xl mb-12',
      className,
    ]),
    children: [
      Div(
        className: centered
            ? 'inline-flex items-center gap-1.5 mb-3'
            : 'flex items-center gap-1.5 mb-3',
        children: [
          if (eyebrowIcon != null)
            hugeIcon(eyebrowIcon, className: 'w-3.5 h-3.5 text-indigo-400'),
          Span(
            className:
                'text-xs font-mono text-indigo-400 font-semibold '
                'uppercase tracking-widest',
            text: eyebrow,
          ),
        ],
      ),
      H2(
        className:
            'text-3xl sm:text-4xl md:text-5xl font-extrabold '
            'text-white tracking-tight leading-tight mb-4',
        text: title,
      ),
      P(
        className: 'text-zinc-400 text-base sm:text-lg leading-relaxed',
        text: description,
      ),
    ],
  );
}
