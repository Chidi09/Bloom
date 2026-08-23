import '../framework.dart';
import 'cn.dart';

/// Visual style variant for [toggle] buttons.
enum ToggleVariant {
  defaultVariant,
  outline,
}

/// Size options for [toggle] buttons.
enum ToggleSize {
  sm,
  defaultSize,
  lg,
}

/// Single two-state toggle button primitive.
///
/// Controlled component supporting accessibility via `aria-pressed`.
BloomNode toggle({
  required bool pressed,
  required void Function(bool pressed) onChange,
  required BloomNode child,
  ToggleVariant variant = ToggleVariant.defaultVariant,
  ToggleSize size = ToggleSize.defaultSize,
  bool disabled = false,
  String extraClassName = '',
}) {
  final variantClass = switch (variant) {
    ToggleVariant.outline =>
      'border border-[var(--border)] bg-transparent hover:bg-[var(--bg-muted)] hover:text-[var(--text)]',
    ToggleVariant.defaultVariant =>
      'bg-transparent hover:bg-[var(--bg-muted)] hover:text-[var(--text)]',
  };

  final sizeClass = switch (size) {
    ToggleSize.sm => 'h-7 px-2 text-xs',
    ToggleSize.lg => 'h-9 px-3 text-sm',
    ToggleSize.defaultSize => 'h-8 px-2.5 text-xs',
  };

  return El(
    'button',
    attrs: {
      'type': 'button',
      'role': 'button',
      'aria-pressed': pressed ? 'true' : 'false',
      'data-slot': 'toggle',
      'data-state': pressed ? 'on' : 'off',
      if (disabled) 'disabled': 'true',
    },
    className: cn([
      'inline-flex items-center justify-center gap-1.5 rounded-[var(--radius-md)] font-medium transition-colors select-none cursor-pointer',
      'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ring)]',
      'disabled:pointer-events-none disabled:opacity-50',
      variantClass,
      sizeClass,
      pressed
          ? 'bg-[var(--bg-muted)] text-[var(--text)] font-semibold shadow-2xs'
          : 'text-[var(--text-muted)]',
      extraClassName,
    ]),
    onClick: disabled ? null : (_) => onChange(!pressed),
    children: [child],
  );
}
