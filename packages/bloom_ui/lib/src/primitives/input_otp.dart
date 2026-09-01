// lib/src/primitives/input_otp.dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../utils/bloom_editable_field.dart';
import '../utils/extensions.dart';

/// A grouped one-time passcode (OTP) input component matching shadcn base-nova design.
///
/// Divides OTP digits into visual groups (e.g. 3-3 format) separated by [BloomInputOTPSeparator],
/// with paste support and auto-focus traversal.
///
/// ```dart
/// BloomInputOTP(
///   length: 6,
///   groupSize: 3,
///   onCompleted: (code) => verifyCode(code),
/// )
/// ```
class BloomInputOTP extends StatefulWidget {
  /// The total number of OTP slots across all groups.
  ///
  /// Defaults to `6`.
  final int length;

  /// The number of digit slots per group before displaying a separator.
  ///
  /// Defaults to `3`.
  final int groupSize;

  /// Callback invoked when all slots are filled.
  final ValueChanged<String> onCompleted;

  /// Callback invoked on each keystroke or paste update.
  final ValueChanged<String>? onChanged;

  /// Whether to obscure the entered digits for security.
  ///
  /// Defaults to `false`.
  final bool obscureText;

  /// Creates a [BloomInputOTP].
  const BloomInputOTP({
    super.key,
    this.length = 6,
    this.groupSize = 3,
    required this.onCompleted,
    this.onChanged,
    this.obscureText = false,
  });

  @override
  State<BloomInputOTP> createState() => _BloomInputOTPState();
}

class _BloomInputOTPState extends State<BloomInputOTP> {
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

  void _onKeyEvent(int index, String value) {
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

  void _onPaste(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    for (int i = 0; i < widget.length && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }
    final next = digits.length < widget.length ? digits.length : widget.length - 1;
    _focusNodes[next].requestFocus();
    final code = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(groups.length, (i) {
        return Row(
          children: [
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: BloomInputOTPSeparator(),
              ),
            groups[i],
          ],
        );
      }),
    );
  }

  List<Widget> _buildGroups(BuildContext context) {
    final List<Widget> groups = [];
    for (int g = 0; g < widget.length; g += widget.groupSize) {
      final end = (g + widget.groupSize).clamp(0, widget.length);
      groups.add(
        BloomInputOTPGroup(
          children: List.generate(end - g, (i) {
            final idx = g + i;
            return BloomInputOTPSlot(
              controller: _controllers[idx],
              focusNode: _focusNodes[idx],
              obscureText: widget.obscureText,
              onChanged: (val) => _onKeyEvent(idx, val),
              onPaste: idx == 0 ? _onPaste : null,
            );
          }),
        ),
      );
    }
    return groups;
  }
}

/// A container card that groups individual [BloomInputOTPSlot] widgets with a rounded border.
class BloomInputOTPGroup extends StatelessWidget {
  /// The slot widgets rendered inside this group.
  final List<Widget> children;

  /// The horizontal spacing between child slots within this group.
  ///
  /// Defaults to `4.0`.
  final double spacing;

  /// Creates a [BloomInputOTPGroup].
  const BloomInputOTPGroup({
    super.key,
    required this.children,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(children.length, (i) {
          return Padding(
            padding: EdgeInsets.only(left: i > 0 ? spacing : 0),
            child: children[i],
          );
        }),
      ),
    );
  }
}

/// A single character slot input within an OTP entry group.
class BloomInputOTPSlot extends StatelessWidget {
  /// The text editing controller for this single character slot.
  final TextEditingController controller;

  /// The focus node managing focus for this slot.
  final FocusNode focusNode;

  /// Whether the input character should be obscured.
  final bool obscureText;

  /// Callback invoked when the single character value changes.
  final ValueChanged<String>? onChanged;

  /// Callback invoked when a pasted multi-character string is detected.
  final ValueChanged<String>? onPaste;

  /// Creates a [BloomInputOTPSlot].
  const BloomInputOTPSlot({
    super.key,
    required this.controller,
    required this.focusNode,
    this.obscureText = false,
    this.onChanged,
    this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;

    return SizedBox(
      width: 40,
      height: 48,
      child: BloomEditableField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          if (onPaste != null) _PasteTextInputFormatter(onPaste!),
        ],
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
          fontFamily: theme.typography.sans,
        ),
        cursorColor: colors.primary,
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(theme.radius.sm),
          border: Border.all(
            color: focusNode.hasFocus ? colors.primary : BloomColors.transparent,
            width: focusNode.hasFocus ? 2 : 0,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _PasteTextInputFormatter extends TextInputFormatter {
  final ValueChanged<String> onPaste;
  const _PasteTextInputFormatter(this.onPaste);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length > 1) {
      onPaste(newValue.text);
      return oldValue;
    }
    return newValue;
  }
}

/// A subtle visual dash divider placed between [BloomInputOTPGroup] groups.
class BloomInputOTPSeparator extends StatelessWidget {
  /// Creates a [BloomInputOTPSeparator].
  const BloomInputOTPSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      width: 8,
      height: 2,
      decoration: BoxDecoration(
        color: colors.border,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
