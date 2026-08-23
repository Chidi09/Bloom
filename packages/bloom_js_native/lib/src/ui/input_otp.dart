import '../events.dart';
import '../framework.dart';
import 'cn.dart';

/// Controlled one-time password (OTP) / PIN input primitive.
BloomNode inputOtp({
  required int length,
  required String value,
  required void Function(String value) onChange,
  bool disabled = false,
  bool hasError = false,
  String extraClassName = '',
}) {
  final chars = List.generate(length, (i) {
    if (i < value.length) return value[i];
    return '';
  });

  return Div(
    attrs: const {'data-slot': 'input-otp'},
    className: cn([
      'inline-flex items-center gap-1.5 select-none',
      extraClassName,
    ]),
    children: List.generate(length, (index) {
      final char = chars[index];

      return El(
        'input',
        attrs: {
          'type': 'text',
          'inputmode': 'numeric',
          'maxlength': '1',
          'value': char,
          'data-slot': 'input-otp-slot',
          if (disabled) 'disabled': 'true',
          if (hasError) 'aria-invalid': 'true',
        },
        className: cn([
          'w-9 h-10 text-center font-mono font-semibold text-sm rounded-[var(--radius-md)] '
          'bg-[var(--card)] text-[var(--text)] border border-[var(--border)] '
          'focus:outline-none focus:ring-2 focus:ring-[var(--ring)] focus:border-[var(--ring)] '
          'transition-all disabled:opacity-50 disabled:cursor-not-allowed',
          hasError ? 'border-[var(--destructive)] focus:ring-[var(--destructive)]' : '',
        ]),
        on: {
          'input': (BloomEvent e) {
            if (disabled) return;
            final inVal = e.value ?? '';
            final nextChars = List<String>.from(chars);
            if (inVal.isNotEmpty) {
              nextChars[index] = inVal[inVal.length - 1];
            } else {
              nextChars[index] = '';
            }
            onChange(nextChars.join());
          },
          'keydown': (BloomEvent e) {
            if (disabled) return;
            if (e.key == 'Backspace' && char.isEmpty && index > 0) {
              final nextChars = List<String>.from(chars);
              nextChars[index - 1] = '';
              onChange(nextChars.join());
            }
          },
        },
      );
    }),
  );
}
