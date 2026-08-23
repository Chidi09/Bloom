import '../events.dart';
import '../framework.dart';
import 'cn.dart';

/// Multi-line text editing primitive for Bloom UI.
BloomNode textarea({
  required String id,
  String? name,
  String? value,
  String? placeholder,
  int rows = 4,
  int? cols,
  bool disabled = false,
  bool required = false,
  bool hasError = false,
  String? ariaDescribedBy,
  String extraClassName = '',
  BloomEventHandler? onInput,
  BloomEventHandler? onChange,
  BloomEventHandler? onFocus,
  BloomEventHandler? onBlur,
  Map<String, String> attrs = const {},
}) {
  final borderRingClass = hasError
      ? 'border-[var(--destructive)] focus:ring-[var(--destructive)]'
      : 'border-[var(--border)] focus:ring-[var(--ring)]';

  return El(
    'textarea',
    attrs: {
      'id': id,
      if (name != null) 'name': name,
      if (placeholder != null) 'placeholder': placeholder,
      if (required) 'required': 'true',
      if (disabled) 'disabled': 'true',
      if (hasError) 'aria-invalid': 'true',
      'rows': '$rows',
      if (cols != null) 'cols': '$cols',
      if (ariaDescribedBy != null) 'aria-describedby': ariaDescribedBy,
      ...attrs,
    },
    className: cn([
      'w-full min-h-[80px] rounded-[var(--radius-sm)] border bg-[var(--bg)] px-3 py-2 text-sm text-[var(--text)] '
      'placeholder:text-[var(--text-faint)] focus:outline-none focus:ring-2 '
      'disabled:cursor-not-allowed disabled:opacity-50 transition-colors resize-y',
      borderRingClass,
      extraClassName,
    ]),
    text: value,
    on: {
      if (onInput != null) 'input': onInput,
      if (onChange != null) 'change': onChange,
      if (onFocus != null) 'focus': onFocus,
      if (onBlur != null) 'blur': onBlur,
    },
  );
}
