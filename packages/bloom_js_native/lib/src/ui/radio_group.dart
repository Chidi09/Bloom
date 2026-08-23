import '../framework.dart';
import 'cn.dart';

/// Controlled radio group primitive.
BloomNode radioGroup({
  required List<({String value, String label})> options,
  required String value,
  required void Function(String value) onChange,
  String? name,
  bool disabled = false,
  String orientation = 'vertical',
  String extraClassName = '',
}) {
  final isHorizontal = orientation == 'horizontal';

  return Div(
    attrs: const {'role': 'radiogroup'},
    className: cn([
      'flex gap-3',
      isHorizontal ? 'flex-row items-center flex-wrap' : 'flex-col',
      extraClassName,
    ]),
    children: options.map((opt) {
      final isSelected = opt.value == value;
      return Div(
        className: 'flex items-center gap-2',
        children: [
          El(
            'input',
            attrs: {
              'type': 'radio',
              if (name != null) 'name': name,
              'value': opt.value,
              if (isSelected) 'checked': 'checked',
              if (disabled) 'disabled': 'true',
            },
            className: cn([
              'w-4 h-4 rounded-full border-[var(--border)] text-[var(--primary)] '
              'focus:ring-2 focus:ring-[var(--ring)] focus:ring-offset-2 focus:ring-offset-[var(--bg)] '
              'accent-[var(--primary)] cursor-pointer disabled:cursor-not-allowed disabled:opacity-50',
            ]),
            on: {
              'change': (_) {
                if (!disabled) onChange(opt.value);
              },
            },
          ),
          El(
            'label',
            className: cn([
              'text-sm font-medium text-[var(--text)] select-none leading-none',
              disabled ? 'cursor-not-allowed opacity-50' : 'cursor-pointer',
            ]),
            onClick: disabled ? null : (_) => onChange(opt.value),
            text: opt.label,
          ),
        ],
      );
    }).toList(),
  );
}
