import 'package:flutter/material.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'style_resolver.dart';

/// Persistent native input controller cache to prevent software keyboard loss and cursor jump.
class BloomNativeInputHost extends StatefulWidget {
  final String? initialValue;
  final String? placeholder;
  final bool isPassword;
  final int maxLines;
  final BloomComputedStyle style;
  final void Function(BloomEvent)? onInput;
  final void Function(BloomEvent)? onChange;

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
