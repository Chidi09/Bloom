import '../events.dart';
import '../framework.dart';
import 'cn.dart';

/// Checkbox primitive with label and indeterminate state support.
BloomNode checkbox({
  required String id,
  String? name,
  bool checked = false,
  bool indeterminate = false,
  bool disabled = false,
  String? label,
  BloomNode? labelNode,
  BloomEventHandler? onChange,
  void Function(bool)? onCheckedChange,
  String extraClassName = '',
  Map<String, String> attrs = const {},
}) {
  final inputAttrs = <String, String>{
    'id': id,
    'type': 'checkbox',
    if (name != null) 'name': name,
    if (checked) 'checked': 'checked',
    if (indeterminate) 'data-indeterminate': 'true',
    if (disabled) 'disabled': 'true',
    if (disabled) 'aria-disabled': 'true',
    ...attrs,
  };

  final inputEl = El(
    'input',
    attrs: inputAttrs,
    className: cn([
      'w-4 h-4 rounded border-[var(--border)] text-[var(--primary)] '
      'focus:ring-2 focus:ring-[var(--ring)] focus:ring-offset-2 focus:ring-offset-[var(--bg)] '
      'accent-[var(--primary)] cursor-pointer disabled:cursor-not-allowed disabled:opacity-50',
      extraClassName,
    ]),
    on: {
      if (onChange != null || onCheckedChange != null)
        'change': (BloomEvent e) {
          onChange?.call(e);
          if (onCheckedChange != null) {
            onCheckedChange(e.checked ?? false);
          }
        },
    },
  );

  if (label == null && labelNode == null) {
    return inputEl;
  }

  return Div(
    className: 'flex items-center gap-2',
    children: [
      inputEl,
      El(
        'label',
        attrs: {'for': id},
        className: cn([
          'text-sm font-medium text-[var(--text)] select-none cursor-pointer leading-none',
          if (disabled) 'cursor-not-allowed opacity-70',
        ]),
        children: [
          if (label != null) Text(label),
          if (labelNode != null) labelNode,
        ],
      ),
    ],
  );
}
