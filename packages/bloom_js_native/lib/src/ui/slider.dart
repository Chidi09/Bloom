import '../events.dart';
import '../framework.dart';
import 'cn.dart';

/// Controlled range slider primitive.
///
/// Uses an accessible native range input styled with CSS design tokens.
BloomNode slider({
  required double value,
  required double min,
  required double max,
  double step = 1,
  required void Function(double value) onChange,
  bool disabled = false,
  String extraClassName = '',
}) {
  return Div(
    attrs: const {'data-slot': 'slider'},
    className: cn(['relative flex items-center w-full select-none', extraClassName]),
    children: [
      El(
        'input',
        attrs: {
          'type': 'range',
          'min': '$min',
          'max': '$max',
          'step': '$step',
          'value': '$value',
          if (disabled) 'disabled': 'true',
        },
        className: cn([
          'w-full h-2 bg-[var(--muted)] rounded-lg appearance-none cursor-pointer '
          'accent-[var(--primary)] focus:outline-none focus:ring-2 focus:ring-[var(--ring)] '
          'disabled:opacity-50 disabled:cursor-not-allowed',
        ]),
        on: {
          'input': (BloomEvent e) {
            if (!disabled) {
              final parsed = double.tryParse(e.value ?? '');
              if (parsed != null) onChange(parsed);
            }
          },
          'change': (BloomEvent e) {
            if (!disabled) {
              final parsed = double.tryParse(e.value ?? '');
              if (parsed != null) onChange(parsed);
            }
          },
        },
      ),
    ],
  );
}
