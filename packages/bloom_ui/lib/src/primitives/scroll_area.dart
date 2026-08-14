// lib/src/primitives/scroll_area.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomScrollArea extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final Axis scrollDirection;
  final EdgeInsetsGeometry? padding;

  const BloomScrollArea({
    super.key,
    required this.child,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(colors.border),
          radius: const Radius.circular(999),
          thickness: WidgetStateProperty.all(6),
        ),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: scrollDirection,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
