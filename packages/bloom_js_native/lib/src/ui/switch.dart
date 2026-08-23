import '../framework.dart';
import 'cn.dart';

/// Toggle switch primitive (named `switchToggle` as `switch` is a reserved word in Dart).
BloomNode switchToggle({
  required bool checked,
  required void Function(bool) onChange,
  bool disabled = false,
  String? id,
  String? name,
  String extraClassName = '',
}) {
  return El(
    'button',
    attrs: {
      'type': 'button',
      'role': 'switch',
      'aria-checked': checked ? 'true' : 'false',
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (disabled) 'disabled': 'true',
    },
    className: cn([
      'relative inline-flex h-5 w-9 shrink-0 items-center rounded-full border-2 border-transparent '
      'transition-colors focus-visible:outline-none focus-visible:ring-2 '
      'focus-visible:ring-[var(--ring)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--bg)]',
      disabled ? 'cursor-not-allowed opacity-50' : 'cursor-pointer',
      checked ? 'bg-[var(--primary)]' : 'bg-[var(--muted)]',
      extraClassName,
    ]),
    onClick: disabled ? null : (_) => onChange(!checked),
    children: [
      Span(
        className: cn([
          'pointer-events-none block h-4 w-4 rounded-full bg-white shadow-sm ring-0 transition-transform',
          checked ? 'translate-x-4' : 'translate-x-0',
        ]),
      ),
    ],
  );
}
