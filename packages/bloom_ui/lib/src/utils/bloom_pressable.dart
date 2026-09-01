// lib/src/utils/bloom_pressable.dart
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'extensions.dart';

/// A Material-free interactive surface: hover, press, focus and hit-testing
/// without an ink ripple.
///
/// Wraps [child] in a composable interaction detector that applies flat color
/// tints on hover, active press, and focus matching shadcn/ui semantics.
///
/// ## Usage
/// ```dart
/// BloomPressable(
///   onTap: () => print('Tapped!'),
///   borderRadius: BorderRadius.circular(8),
///   child: Text('Press me'),
/// );
/// ```
class BloomPressable extends StatefulWidget {
  /// The widget below this interactive surface.
  final Widget child;

  /// Called when the surface is tapped.
  final VoidCallback? onTap;

  /// Called when a tap down event occurs with pointer details.
  final GestureTapDownCallback? onTapDown;

  /// Called when the surface is pressed for a long duration.
  final VoidCallback? onLongPress;

  /// Called when a pointer enters or exits the interactive bounds.
  final ValueChanged<bool>? onHover;

  /// Called when the focus state changes.
  final ValueChanged<bool>? onFocusChange;

  /// The border radius applied to the feedback overlay tint.
  final BorderRadius? borderRadius;

  /// The overlay color applied when hovered. Defaults to a subtle opacity tint on [textPrimary].
  final Color? hoverColor;

  /// The overlay color applied when pressed. Defaults to a medium opacity tint on [textPrimary].
  final Color? pressedColor;

  /// The overlay color applied when keyboard-focused. Defaults to a subtle opacity tint on [textPrimary].
  final Color? focusColor;

  /// The cursor for mouse pointers entering this surface.
  final MouseCursor? mouseCursor;

  /// Whether this pressable surface is active and interactive.
  final bool enabled;

  /// Whether this widget should automatically request focus on launch.
  final bool autofocus;

  /// An optional focus node to manage focus state externally.
  final FocusNode? focusNode;

  /// Whether this widget can request focus when interacted with.
  final bool canRequestFocus;

  /// How to behave during hit testing. Defaults to [HitTestBehavior.opaque].
  final HitTestBehavior behavior;

  /// Inner padding applied between the surface tint and [child].
  final EdgeInsetsGeometry? padding;

  /// Creates a [BloomPressable] interactive surface.
  const BloomPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.borderRadius,
    this.hoverColor,
    this.pressedColor,
    this.focusColor,
    this.mouseCursor,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.canRequestFocus = true,
    this.behavior = HitTestBehavior.opaque,
    this.padding,
  });

  @override
  State<BloomPressable> createState() => _BloomPressableState();
}

class _BloomPressableState extends State<BloomPressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final effectivePressed = widget.pressedColor ?? colors.textPrimary.withValues(alpha: 0.12);
    final effectiveHover = widget.hoverColor ?? colors.textPrimary.withValues(alpha: 0.06);
    final effectiveFocus = widget.focusColor ?? colors.textPrimary.withValues(alpha: 0.08);

    final Color overlay;
    if (!widget.enabled) {
      overlay = BloomColors.transparent;
    } else if (_pressed) {
      overlay = effectivePressed;
    } else if (_hovered) {
      overlay = effectiveHover;
    } else if (_focused) {
      overlay = effectiveFocus;
    } else {
      overlay = BloomColors.transparent;
    }

    final cursor = widget.mouseCursor ??
        (widget.enabled && widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic);

    Widget result = AnimatedContainer(
      duration: BloomMotion.instant,
      curve: BloomMotion.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: overlay,
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );

    result = GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.enabled
          ? (details) {
              setState(() => _pressed = true);
              widget.onTapDown?.call(details);
            }
          : null,
      onTapUp: widget.enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.enabled && widget.onTap != null ? widget.onTap : null,
      onLongPress: widget.enabled && widget.onLongPress != null ? widget.onLongPress : null,
      child: result,
    );

    result = MouseRegion(
      cursor: cursor,
      onEnter: widget.enabled
          ? (_) {
              setState(() => _hovered = true);
              widget.onHover?.call(true);
            }
          : null,
      onExit: widget.enabled
          ? (_) {
              setState(() => _hovered = false);
              widget.onHover?.call(false);
            }
          : null,
      child: result,
    );

    result = Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: widget.enabled && widget.canRequestFocus,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        widget.onFocusChange?.call(focused);
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) => widget.enabled ? widget.onTap?.call() : null,
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (intent) => widget.enabled ? widget.onTap?.call() : null,
          ),
        },
        child: result,
      ),
    );

    return Semantics(
      button: true,
      enabled: widget.enabled,
      onTap: widget.enabled ? widget.onTap : null,
      child: result,
    );
  }
}
