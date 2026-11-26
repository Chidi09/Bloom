import '../framework.dart';
import '../signals.dart';
import 'cn.dart';

/// Country calling-code descriptor for [phoneInput].
class PhoneCountryCode {
  /// ISO 3166-1 alpha-2 code (e.g. `'US'`).
  final String code;

  /// International dial prefix (e.g. `'+1'`).
  final String dialCode;

  /// Display label.
  final String label;

  /// Creates a [PhoneCountryCode].
  const PhoneCountryCode({
    required this.code,
    required this.dialCode,
    required this.label,
  });
}

const List<PhoneCountryCode> _defaultCountries = [
  PhoneCountryCode(code: 'US', dialCode: '+1', label: 'US (+1)'),
  PhoneCountryCode(code: 'GB', dialCode: '+44', label: 'UK (+44)'),
  PhoneCountryCode(code: 'DE', dialCode: '+49', label: 'DE (+49)'),
  PhoneCountryCode(code: 'NG', dialCode: '+234', label: 'NG (+234)'),
];

/// International telephone input combining country dial code selector and number field.
BloomNode phoneInput({
  Signal<String>? countryDialCode,
  Signal<String>? number,
  List<PhoneCountryCode>? countries,
  String placeholder = '555-0100',
  void Function(String fullNumber)? onChanged,
  String extraClassName = '',
}) {
  final list = countries ?? _defaultCountries;
  final dialSig =
      countryDialCode ?? signal<String>(list.isNotEmpty ? list.first.dialCode : '+1');
  final numSig = number ?? signal<String>('');

  void notify() {
    onChanged?.call('${dialSig.value}${numSig.value}');
  }

  return Div(
    className: cn([
      'flex items-center w-full rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--bg)] overflow-hidden',
      extraClassName,
    ]),
    children: [
      Select(
        attrs: const {'aria-label': 'Country code'},
        className:
            'h-9 px-2.5 bg-[var(--bg-soft)] border-r border-[var(--border)] text-sm text-[var(--text)] focus:outline-none',
        onChange: (e) {
          if (e.value != null && e.value!.isNotEmpty) {
            dialSig.value = e.value!;
            notify();
          }
        },
        children: [
          for (final c in list)
            Option(
              value: c.dialCode,
              selected: dialSig.value == c.dialCode,
              text: c.label,
            ),
        ],
      ),
      Input(
        type: 'tel',
        placeholder: placeholder,
        value: numSig.value,
        attrs: const {'aria-label': 'Phone number'},
        className:
            'flex-1 h-9 px-3 bg-transparent text-sm text-[var(--text)] focus:outline-none',
        onInput: (e) {
          numSig.value = e.value ?? '';
          notify();
        },
      ),
    ],
  );
}
