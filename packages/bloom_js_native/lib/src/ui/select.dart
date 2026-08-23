import '../events.dart';
import '../framework.dart';
import 'cn.dart';

/// Native styled `<select>` dropdown primitive for Bloom UI.
BloomNode selectInput({
  required String id,
  String? name,
  required String value,
  required List<({String value, String label})> options,
  bool disabled = false,
  bool hasError = false,
  String? placeholder,
  BloomEventHandler? onChange,
  void Function(String)? onValueChange,
  String extraClassName = '',
  Map<String, String> attrs = const {},
}) {
  final borderRingClass = hasError
      ? 'border-[var(--destructive)] focus:ring-[var(--destructive)]'
      : 'border-[var(--border)] focus:ring-[var(--ring)]';

  return El(
    'select',
    attrs: {
      'id': id,
      if (name != null) 'name': name,
      if (disabled) 'disabled': 'true',
      if (hasError) 'aria-invalid': 'true',
      ...attrs,
    },
    className: cn([
      'w-full rounded-[var(--radius-sm)] border bg-[var(--bg)] px-3 py-2 text-sm text-[var(--text)] '
      'focus:outline-none focus:ring-2 disabled:cursor-not-allowed disabled:opacity-50 transition-colors cursor-pointer',
      borderRingClass,
      extraClassName,
    ]),
    on: {
      if (onChange != null || onValueChange != null)
        'change': (BloomEvent e) {
          onChange?.call(e);
          if (onValueChange != null && e.value != null) {
            onValueChange(e.value!);
          }
        },
    },
    children: [
      if (placeholder != null)
        El(
          'option',
          attrs: {
            'value': '',
            'disabled': 'true',
            if (value.isEmpty) 'selected': 'selected',
          },
          text: placeholder,
        ),
      ...options.map(
        (opt) => El(
          'option',
          attrs: {
            'value': opt.value,
            if (opt.value == value) 'selected': 'selected',
          },
          text: opt.label,
        ),
      ),
    ],
  );
}
