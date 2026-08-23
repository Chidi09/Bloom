import '../framework.dart';
import 'cn.dart';

enum AvatarSize {
  sm,
  md,
  lg,
}

/// Avatar primitive with image and fallback initials.
BloomNode avatar({
  String? src,
  String? alt,
  String? fallbackText,
  AvatarSize size = AvatarSize.md,
  String extraClassName = '',
  BloomNode? badge,
  Map<String, String> attrs = const {},
}) {
  String sizeClass;
  String textSizeClass;
  switch (size) {
    case AvatarSize.sm:
      sizeClass = 'w-6 h-6';
      textSizeClass = 'text-[10px]';
      break;
    case AvatarSize.md:
      sizeClass = 'w-8 h-8';
      textSizeClass = 'text-xs';
      break;
    case AvatarSize.lg:
      sizeClass = 'w-10 h-10';
      textSizeClass = 'text-sm';
      break;
  }

  final hasImage = src != null && src.isNotEmpty;

  return Div(
    attrs: attrs,
    className: cn([
      'relative inline-flex shrink-0 rounded-full select-none overflow-hidden',
      sizeClass,
      extraClassName,
    ]),
    children: [
      if (hasImage)
        Img(
          src: src,
          alt: alt ?? 'Avatar',
          className: 'aspect-square h-full w-full object-cover rounded-full',
        )
      else
        Span(
          className: cn([
            'flex h-full w-full items-center justify-center rounded-full '
            'bg-[var(--muted)] text-[var(--muted-foreground)] font-medium uppercase',
            textSizeClass,
          ]),
          text: fallbackText ?? '?',
        ),
      if (badge != null)
        Div(
          className:
              'absolute bottom-0 right-0 z-10 inline-flex items-center justify-center rounded-full ring-2 ring-[var(--bg)]',
          children: [badge],
        ),
    ],
  );
}

/// Avatar group container overlapping multiple avatars.
BloomNode avatarGroup({
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return Div(
    className: cn([
      'flex items-center -space-x-2 *:ring-2 *:ring-[var(--bg)]',
      extraClassName,
    ]),
    children: children,
  );
}
