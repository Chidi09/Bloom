// lib/src/primitives/resizable.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomResizable extends StatefulWidget {
  final Widget startChild;
  final Widget endChild;
  final Axis axis;
  final double initialRatio;
  final double minRatio;
  final double maxRatio;
  final ValueChanged<double>? onRatioChanged;

  const BloomResizable({
    super.key,
    required this.startChild,
    required this.endChild,
    this.axis = Axis.horizontal,
    this.initialRatio = 0.5,
    this.minRatio = 0.2,
    this.maxRatio = 0.8,
    this.onRatioChanged,
  });

  @override
  State<BloomResizable> createState() => _BloomResizableState();
}

class _BloomResizableState extends State<BloomResizable> {
  double _ratio = 0.5;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio.clamp(widget.minRatio, widget.maxRatio);
  }

  void _onDragUpdate(DragUpdateDetails details, double totalSize) {
    final delta = widget.axis == Axis.horizontal ? details.delta.dx : details.delta.dy;
    final newRatio = (_ratio + delta / totalSize).clamp(widget.minRatio, widget.maxRatio);
    setState(() => _ratio = newRatio);
    widget.onRatioChanged?.call(newRatio);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.axis == Axis.horizontal) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final total = constraints.maxWidth;
          final startSize = total * _ratio;
          return Row(
            children: [
              SizedBox(width: startSize, child: widget.startChild),
              BloomResizableHandle(
                axis: widget.axis,
                onDragUpdate: (d) => _onDragUpdate(d, total),
              ),
              Expanded(child: widget.endChild),
            ],
          );
        },
      );
    } else {
      return LayoutBuilder(
        builder: (context, constraints) {
          final total = constraints.maxHeight;
          final startSize = total * _ratio;
          return Column(
            children: [
              SizedBox(height: startSize, child: widget.startChild),
              BloomResizableHandle(
                axis: widget.axis,
                onDragUpdate: (d) => _onDragUpdate(d, total),
              ),
              Expanded(child: widget.endChild),
            ],
          );
        },
      );
    }
  }
}

class BloomResizableHandle extends StatelessWidget {
  final Axis axis;
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  const BloomResizableHandle({
    super.key,
    required this.axis,
    required this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final isHorizontal = axis == Axis.horizontal;

    return Semantics(
      label: 'Resize handle',
      child: MouseRegion(
        cursor: isHorizontal ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          onHorizontalDragUpdate: isHorizontal ? onDragUpdate : null,
          onVerticalDragUpdate: !isHorizontal ? onDragUpdate : null,
          child: Container(
            width: isHorizontal ? 1 : double.infinity,
            height: isHorizontal ? double.infinity : 1,
            color: colors.border,
          ),
        ),
      ),
    );
  }
}
