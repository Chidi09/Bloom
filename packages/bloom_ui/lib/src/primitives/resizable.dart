// lib/src/primitives/resizable.dart
import 'package:flutter/widgets.dart';
import '../utils/extensions.dart';

/// A split-pane container that allows the user to resize two adjacent children by dragging a handle.
///
/// Divides available space between [startChild] and [endChild] along [axis] based on a proportional ratio
/// clamped between [minRatio] and [maxRatio].
///
/// ```dart
/// BloomResizable(
///   axis: Axis.horizontal,
///   initialRatio: 0.3,
///   minRatio: 0.15,
///   maxRatio: 0.85,
///   onRatioChanged: (ratio) => print('New ratio: $ratio'),
///   startChild: Sidebar(),
///   endChild: MainContent(),
/// );
/// ```
class BloomResizable extends StatefulWidget {
  /// The leading child widget (left pane when horizontal, top pane when vertical).
  final Widget startChild;

  /// The trailing child widget (right pane when horizontal, bottom pane when vertical).
  final Widget endChild;

  /// The orientation of the resize split.
  ///
  /// Defaults to [Axis.horizontal].
  final Axis axis;

  /// The initial split ratio assigned to [startChild] (between 0.0 and 1.0).
  ///
  /// Defaults to `0.5`.
  final double initialRatio;

  /// The minimum proportional split ratio allowed for [startChild].
  ///
  /// Defaults to `0.2`.
  final double minRatio;

  /// The maximum proportional split ratio allowed for [startChild].
  ///
  /// Defaults to `0.8`.
  final double maxRatio;

  /// Callback invoked whenever the user drags the resize handle to a new ratio.
  final ValueChanged<double>? onRatioChanged;

  /// Creates a [BloomResizable] split pane.
  ///
  /// The [startChild] and [endChild] widgets are required.
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

/// An interactive handle rendered between resizable panes that captures drag updates.
///
/// Changes cursor on hover ([SystemMouseCursors.resizeLeftRight] or [SystemMouseCursors.resizeUpDown])
/// and renders a 1px border line using [BloomColorScheme.border].
class BloomResizableHandle extends StatelessWidget {
  /// The orientation of the split containing this handle.
  final Axis axis;

  /// Callback fired as the handle is dragged with [DragUpdateDetails].
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  /// Creates a [BloomResizableHandle].
  ///
  /// Both [axis] and [onDragUpdate] are required.
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
