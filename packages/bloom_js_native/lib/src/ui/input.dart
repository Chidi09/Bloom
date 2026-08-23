import '../events.dart';
import '../framework.dart';
import 'cn.dart';

/// Text input primitive for Bloom UI.
BloomNode textInput({
  required String id,
  String? name,
  String? value,
  String? placeholder,
  String type = 'text',
  String? prefix,
  BloomNode? prefixNode,
  String? suffix,
  BloomNode? suffixNode,
  bool disabled = false,
  bool required = false,
  bool hasError = false,
  String? ariaDescribedBy,
  String extraClassName = '',
  BloomEventHandler? onInput,
  BloomEventHandler? onChange,
  BloomEventHandler? onKeyDown,
  BloomEventHandler? onFocus,
  BloomEventHandler? onBlur,
  Map<String, String> attrs = const {},
}) {
  final borderRingClass = hasError
      ? 'border-[var(--destructive)] focus:ring-[var(--destructive)]'
      : 'border-[var(--border)] focus:ring-[var(--ring)]';

  final inputAttrs = <String, String>{
    'id': id,
    'type': type,
    if (name != null) 'name': name,
    if (value != null) 'value': value,
    if (placeholder != null) 'placeholder': placeholder,
    if (required) 'required': 'true',
    if (disabled) 'disabled': 'true',
    if (hasError) 'aria-invalid': 'true',
    if (ariaDescribedBy != null) 'aria-describedby': ariaDescribedBy,
    ...attrs,
  };

  final hasPrefix = prefix != null || prefixNode != null;
  final hasSuffix = suffix != null || suffixNode != null;

  final inputEl = El(
    'input',
    attrs: inputAttrs,
    className: cn([
      'w-full rounded-[var(--radius-sm)] border bg-[var(--bg)] text-sm text-[var(--text)] '
      'placeholder:text-[var(--text-faint)] focus:outline-none focus:ring-2 '
      'disabled:cursor-not-allowed disabled:opacity-50 transition-colors',
      hasPrefix ? 'pl-8' : 'px-3',
      hasSuffix ? 'pr-8' : 'px-3',
      'py-2',
      borderRingClass,
      extraClassName,
    ]),
    on: {
      if (onInput != null) 'input': onInput,
      if (onChange != null) 'change': onChange,
      if (onKeyDown != null) 'keydown': onKeyDown,
      if (onFocus != null) 'focus': onFocus,
      if (onBlur != null) 'blur': onBlur,
    },
  );

  if (!hasPrefix && !hasSuffix) {
    return inputEl;
  }

  return Div(
    className: 'relative flex items-center w-full',
    children: [
      if (prefixNode != null)
        Div(
          className:
              'absolute left-2.5 flex items-center text-sm text-[var(--text-muted)] pointer-events-none select-none',
          children: [prefixNode],
        )
      else if (prefix != null)
        Span(
          className:
              'absolute left-2.5 text-sm text-[var(--text-muted)] pointer-events-none select-none',
          text: prefix,
        ),
      inputEl,
      if (suffixNode != null)
        Div(
          className:
              'absolute right-2.5 flex items-center text-sm text-[var(--text-muted)] pointer-events-none select-none',
          children: [suffixNode],
        )
      else if (suffix != null)
        Span(
          className:
              'absolute right-2.5 text-sm text-[var(--text-muted)] pointer-events-none select-none',
          text: suffix,
        ),
    ],
  );
}
