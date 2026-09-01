// lib/src/utils/bloom_modal_routes.dart
import 'package:flutter/widgets.dart';

import '../theme/bloom_theme.dart';
import '../theme/bloom_theme_provider.dart';
import '../theme/tokens.dart';
import 'extensions.dart';

/// The screen edge from which a modal sheet originates and slides in.
enum BloomSheetSide {
  /// Slides in from the top edge of the screen.
  top,

  /// Slides in from the bottom edge of the screen.
  bottom,

  /// Slides in from the left edge of the screen.
  left,

  /// Slides in from the right edge of the screen.
  right,
}

/// Shows [builder] as a modal centred dialog. Material-free replacement for `showDialog`.
Future<T?> showBloomDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Duration transitionDuration = const Duration(milliseconds: 180),
}) {
  final BloomTheme theme = context.bloomTheme;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ?? (barrierDismissible ? 'Dismiss' : null),
    barrierColor: barrierColor ?? BloomColors.black.withValues(alpha: 0.55),
    transitionDuration: transitionDuration,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
      return BloomThemeProvider(
        theme: theme,
        child: builder(buildContext),
      );
    },
    transitionBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

/// Shows [builder] as a modal sheet anchored to one edge. Material-free replacement
/// for `showModalBottomSheet`.
Future<T?> showBloomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  BloomSheetSide side = BloomSheetSide.bottom,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? barrierColor,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Duration transitionDuration = const Duration(milliseconds: 240),
}) {
  final BloomTheme theme = context.bloomTheme;

  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _BloomSheetRoute<T>(
      builder: builder,
      theme: theme,
      side: side,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      barrierColor: barrierColor ?? BloomColors.black.withValues(alpha: 0.55),
      settings: routeSettings,
      transitionDuration: transitionDuration,
    ),
  );
}

class _BloomSheetRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final BloomTheme theme;
  final BloomSheetSide side;
  final bool isDismissible;
  final bool enableDrag;
  final Color _barrierColor;

  @override
  final Duration transitionDuration;

  _BloomSheetRoute({
    required this.builder,
    required this.theme,
    required this.side,
    required this.isDismissible,
    required this.enableDrag,
    required Color barrierColor,
    super.settings,
    this.transitionDuration = const Duration(milliseconds: 240),
  })  : _barrierColor = barrierColor;

  @override
  Color? get barrierColor => _barrierColor;

  @override
  bool get barrierDismissible => isDismissible;

  @override
  String? get barrierLabel => isDismissible ? 'Dismiss' : null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    Widget child = BloomThemeProvider(
      theme: theme,
      child: SafeArea(
        child: builder(context),
      ),
    );

    if (enableDrag) {
      child = _BloomDraggableSheet(
        side: side,
        onDismiss: () => Navigator.of(context).pop(),
        child: child,
      );
    }

    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    final Offset beginOffset = switch (side) {
      BloomSheetSide.top => const Offset(0.0, -1.0),
      BloomSheetSide.bottom => const Offset(0.0, 1.0),
      BloomSheetSide.left => const Offset(-1.0, 0.0),
      BloomSheetSide.right => const Offset(1.0, 0.0),
    };

    final Alignment alignment = switch (side) {
      BloomSheetSide.top => Alignment.topCenter,
      BloomSheetSide.bottom => Alignment.bottomCenter,
      BloomSheetSide.left => Alignment.centerLeft,
      BloomSheetSide.right => Alignment.centerRight,
    };

    return Align(
      alignment: alignment,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

class _BloomDraggableSheet extends StatefulWidget {
  final BloomSheetSide side;
  final VoidCallback onDismiss;
  final Widget child;

  const _BloomDraggableSheet({
    required this.side,
    required this.onDismiss,
    required this.child,
  });

  @override
  State<_BloomDraggableSheet> createState() => _BloomDraggableSheetState();
}

class _BloomDraggableSheetState extends State<_BloomDraggableSheet>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  late AnimationController _springController;
  Animation<Offset>? _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        if (_springAnimation != null) {
          setState(() {
            _dragOffset = _springAnimation!.value;
          });
        }
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, Size size) {
    _springController.stop();
    setState(() {
      switch (widget.side) {
        case BloomSheetSide.bottom:
          final newY = _dragOffset.dy + details.delta.dy;
          _dragOffset = Offset(0, newY < 0 ? 0 : newY);
        case BloomSheetSide.top:
          final newY = _dragOffset.dy + details.delta.dy;
          _dragOffset = Offset(0, newY > 0 ? 0 : newY);
        case BloomSheetSide.left:
          final newX = _dragOffset.dx + details.delta.dx;
          _dragOffset = Offset(newX > 0 ? 0 : newX, 0);
        case BloomSheetSide.right:
          final newX = _dragOffset.dx + details.delta.dx;
          _dragOffset = Offset(newX < 0 ? 0 : newX, 0);
      }
    });
  }

  void _onDragEnd(DragEndDetails details, Size size) {
    final velocity = details.primaryVelocity ?? 0.0;
    bool shouldDismiss = false;

    switch (widget.side) {
      case BloomSheetSide.bottom:
        if (_dragOffset.dy > size.height * 0.4 || velocity > 800) {
          shouldDismiss = true;
        }
      case BloomSheetSide.top:
        if (_dragOffset.dy.abs() > size.height * 0.4 || velocity < -800) {
          shouldDismiss = true;
        }
      case BloomSheetSide.left:
        if (_dragOffset.dx.abs() > size.width * 0.4 || velocity < -800) {
          shouldDismiss = true;
        }
      case BloomSheetSide.right:
        if (_dragOffset.dx > size.width * 0.4 || velocity > 800) {
          shouldDismiss = true;
        }
    }

    if (shouldDismiss) {
      widget.onDismiss();
    } else {
      _springAnimation = Tween<Offset>(
        begin: _dragOffset,
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
      );
      _springController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final isVertical =
            widget.side == BloomSheetSide.bottom || widget.side == BloomSheetSide.top;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: isVertical ? (d) => _onDragUpdate(d, size) : null,
          onVerticalDragEnd: isVertical ? (d) => _onDragEnd(d, size) : null,
          onHorizontalDragUpdate: !isVertical ? (d) => _onDragUpdate(d, size) : null,
          onHorizontalDragEnd: !isVertical ? (d) => _onDragEnd(d, size) : null,
          child: Transform.translate(
            offset: _dragOffset,
            child: widget.child,
          ),
        );
      },
    );
  }
}
