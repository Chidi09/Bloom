import 'package:flutter/material.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'style_resolver.dart';

/// Persistent native input controller host that manages software keyboard focus and cursor stability.
///
/// Wraps a Flutter [TextField] configured with the computed styles ([BloomComputedStyle])
/// derived from Tailwind-like CSS classes and inline styles on `<input>` and `<textarea>` elements.
///
/// Example:
/// ```dart
/// BloomNativeInputHost(
///   initialValue: 'user@example.com',
///   placeholder: 'Enter email...',
///   style: BloomStyleResolver.resolve('p-2 bg-zinc-800 text-white rounded-md'),
///   onInput: (event) => print('Typing: ${event.value}'),
/// )
/// ```
class BloomNativeInputHost extends StatefulWidget {
  /// Initial text value populated in the text editing controller.
  final String? initialValue;

  /// Placeholder hint text rendered when the field is empty.
  final String? placeholder;

  /// Whether characters should be masked for password input (defaults to false).
  final bool isPassword;

  /// Maximum number of lines for multi-line inputs (e.g. 3 for textarea, 1 for input).
  final int maxLines;

  /// Computed style containing fonts, colors, padding, and border radius.
  final BloomComputedStyle style;

  /// Event callback invoked on every input keystroke.
  final void Function(BloomEvent)? onInput;

  /// Event callback invoked when editing completes or value changes.
  final void Function(BloomEvent)? onChange;

  /// Creates a [BloomNativeInputHost] widget.
  const BloomNativeInputHost({
    super.key,
    this.initialValue,
    this.placeholder,
    this.isPassword = false,
    this.maxLines = 1,
    required this.style,
    this.onInput,
    this.onChange,
  });

  @override
  State<BloomNativeInputHost> createState() => _BloomNativeInputHostState();
}

class _BloomNativeInputHostState extends State<BloomNativeInputHost> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(covariant BloomNativeInputHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != null && widget.initialValue != _controller.text) {
      final oldSelection = _controller.selection;
      _controller.text = widget.initialValue!;
      if (oldSelection.isValid && oldSelection.end <= widget.initialValue!.length) {
        _controller.selection = oldSelection;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      obscureText: widget.isPassword,
      maxLines: widget.maxLines,
      style: TextStyle(
        fontSize: widget.style.fontSize,
        color: widget.style.textColor ?? Colors.white,
        fontFamily: widget.style.fontFamily,
        fontWeight: widget.style.fontWeight,
      ),
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: const TextStyle(color: Color(0xFF52525B), fontSize: 13),
        filled: true,
        fillColor: widget.style.backgroundColor ?? const Color(0xFF14141A),
        contentPadding: widget.style.padding.isNonNegative ? widget.style.padding : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: widget.style.borderRadius ?? BorderRadius.circular(8),
          borderSide: BorderSide(color: widget.style.borderColor ?? const Color(0xFF1E1E24)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: widget.style.borderRadius ?? BorderRadius.circular(8),
          borderSide: BorderSide(color: widget.style.borderColor ?? const Color(0xFF1E1E24)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: widget.style.borderRadius ?? BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
      ),
      onChanged: (val) {
        widget.onInput?.call(BloomEvent(type: 'input', value: val));
        widget.onChange?.call(BloomEvent(type: 'change', value: val));
      },
    );
  }
}
