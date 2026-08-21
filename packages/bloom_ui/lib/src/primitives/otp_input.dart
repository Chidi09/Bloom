// lib/src/primitives/otp_input.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/extensions.dart';

/// A multi-digit one-time passcode (OTP) input row primitive.
///
/// Automatically advances focus to the next field when a digit is entered, moves back on deletion,
/// and calls [onCompleted] once all slots are populated.
///
/// ```dart
/// BloomOtpInput(
///   length: 6,
///   onCompleted: (code) => print('OTP: $code'),
///   onChanged: (code) => print('Typing: $code'),
/// )
/// ```
class BloomOtpInput extends StatefulWidget {
  /// The total number of digit input cells.
  ///
  /// Defaults to `6`.
  final int length;

  /// Callback invoked when all [length] digits have been entered.
  final ValueChanged<String> onCompleted;

  /// Callback invoked whenever the value of any digit slot changes.
  final ValueChanged<String>? onChanged;

  /// Whether to obscure entered digits (e.g. for PIN or password codes).
  ///
  /// Defaults to `false`.
  final bool obscureText;

  /// Creates a [BloomOtpInput].
  const BloomOtpInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.obscureText = false,
  });

  @override
  State<BloomOtpInput> createState() => _BloomOtpInputState();
}

class _BloomOtpInputState extends State<BloomOtpInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    final code = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: 44,
          height: 52,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            obscureText: widget.obscureText,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: colors.surface2,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.bloomRadius.md),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.bloomRadius.md),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.bloomRadius.md),
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
            ),
            onChanged: (val) => _onDigitChanged(index, val),
          ),
        );
      }),
    );
  }
}
