// lib/src/primitives/phone_input.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'input.dart';

/// A specialized phone number text field with a country dialing prefix and formatting hints.
///
/// Example:
/// ```dart
/// BloomPhoneInput(
///   countryCode: '+1',
///   onChanged: (phone) => print(phone),
/// )
/// ```
class BloomPhoneInput extends StatelessWidget {
  /// Optional text editing controller.
  final TextEditingController? controller;

  /// Initial phone number string when uncontrolled.
  final String? initialValue;

  /// Callback fired when the phone number input changes.
  final ValueChanged<String>? onChanged;

  /// Dialing code prefix displayed beside the input. Defaults to `'+1'`.
  final String countryCode;

  /// Creates a [BloomPhoneInput].
  const BloomPhoneInput({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.countryCode = '+1',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return BloomInput(
      controller: controller,
      initialValue: initialValue,
      onChanged: onChanged,
      keyboardType: TextInputType.phone,
      hintText: '(555) 000-0000',
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              countryCode,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 20, color: colors.border),
          ],
        ),
      ),
    );
  }
}
