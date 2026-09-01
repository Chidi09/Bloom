// lib/src/utils/bloom_toast_host.dart
import 'dart:async';
import 'package:flutter/widgets.dart';

import '../theme/bloom_theme.dart';
import '../theme/bloom_theme_provider.dart';
import 'extensions.dart';

/// Screen placement alignment for transient toast notifications.
enum BloomToastAlignment {
  /// Top-left viewport alignment.
  topLeft,

  /// Centered top viewport alignment.
  topCenter,

  /// Top-right viewport alignment.
  topRight,

  /// Bottom-left viewport alignment.
  bottomLeft,

  /// Centered bottom viewport alignment.
  bottomCenter,

  /// Bottom-right viewport alignment.
  bottomRight,
}

/// A handle to an active transient toast that allows manual dismissal and awaiting its close lifecycle.
class BloomToastHandle {
  final VoidCallback _dismiss;
  final Future<void> _closed;

  BloomToastHandle._({
    required VoidCallback dismiss,
    required Future<void> closed,
  })  : _dismiss = dismiss,
        _closed = closed;

  /// Dismisses this toast immediately with an exit animation.
  void dismiss() => _dismiss();

  /// Future that completes when this toast has finished animating out and its overlay entry is removed.
  Future<void> get closed => _closed;
}

class _ToastRecord {
  final OverlayEntry entry;
  final GlobalKey<_BloomToastItemWidgetState> key;
  final BloomToastAlignment alignment;
  final Completer<void> closedCompleter;
  final ValueNotifier<int> indexNotifier;
  final OverlayState overlay;
  Timer? timer;
  bool isDismissing = false;

  _ToastRecord({
    required this.entry,
    required this.key,
    required this.alignment,
    required this.closedCompleter,
    required this.indexNotifier,
    required this.overlay,
  });
}

/// Hosts transient Bloom toasts in the nearest [Overlay]. Material-free replacement
/// for `ScaffoldMessenger`.
class BloomToastHost {
  BloomToastHost._();

  static final List<_ToastRecord> _activeRecords = <_ToastRecord>[];

  /// Shows [child] as a transient overlay entry and returns a handle that dismisses it.
  static BloomToastHandle show(
    BuildContext context, {
    required Widget child,
    Duration duration = const Duration(seconds: 4),
    BloomToastAlignment alignment = BloomToastAlignment.bottomCenter,
  }) {
    final BloomTheme theme = context.bloomTheme;
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    final Completer<void> closedCompleter = Completer<void>();
    final GlobalKey<_BloomToastItemWidgetState> itemKey =
        GlobalKey<_BloomToastItemWidgetState>();

    final sameAlignmentRecords =
        _activeRecords.where((r) => r.alignment == alignment && r.overlay == overlay).toList();
    final ValueNotifier<int> indexNotifier = ValueNotifier<int>(sameAlignmentRecords.length);

    late final _ToastRecord record;
    late final OverlayEntry overlayEntry;

    void dismissToast() {
      if (record.isDismissing) return;
      record.isDismissing = true;
      record.timer?.cancel();
      record.timer = null;

      final state = itemKey.currentState;
      if (state != null) {
        state.animateOut().then((_) {
          _removeRecord(record);
        });
      } else {
        _removeRecord(record);
      }
    }

    overlayEntry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return BloomThemeProvider(
          theme: theme,
          child: _BloomToastItemWidget(
            key: itemKey,
            alignment: alignment,
            indexListenable: indexNotifier,
            onDismissRequest: dismissToast,
            onDisposed: () {
              // The overlay can be torn down before the auto-dismiss timer
              // fires (route popped, app shut down, widget test ended). The
              // timer must not outlive the widget that scheduled it.
              record.timer?.cancel();
              record.timer = null;
              _activeRecords.remove(record);
              if (!record.closedCompleter.isCompleted) {
                record.closedCompleter.complete();
              }
            },
            child: child,
          ),
        );
      },
    );

    record = _ToastRecord(
      entry: overlayEntry,
      key: itemKey,
      alignment: alignment,
      closedCompleter: closedCompleter,
      indexNotifier: indexNotifier,
      overlay: overlay,
    );

    _activeRecords.add(record);
    overlay.insert(overlayEntry);

    if (duration > Duration.zero) {
      record.timer = Timer(duration, dismissToast);
    }

    return BloomToastHandle._(
      dismiss: dismissToast,
      closed: closedCompleter.future,
    );
  }

  static void _removeRecord(_ToastRecord record) {
    record.timer?.cancel();
    record.timer = null;
    try {
      if (record.entry.mounted) {
        record.entry.remove();
      }
    } finally {
      _activeRecords.remove(record);
      if (!record.closedCompleter.isCompleted) {
        record.closedCompleter.complete();
      }
      _reindex(record.overlay, record.alignment);
    }
  }

  static void _reindex(OverlayState overlay, BloomToastAlignment alignment) {
    final matching =
        _activeRecords.where((r) => r.alignment == alignment && r.overlay == overlay).toList();
    for (int i = 0; i < matching.length; i++) {
      matching[i].indexNotifier.value = i;
    }
  }

  /// Dismisses every visible toast in [context]'s overlay.
  static void dismissAll(BuildContext context) {
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    final recordsToDismiss =
        _activeRecords.where((r) => r.overlay == overlay).toList();
    for (final record in recordsToDismiss) {
      record.timer?.cancel();
      record.timer = null;
      record.isDismissing = true;
      final state = record.key.currentState;
      if (state != null) {
        state.animateOut().then((_) {
          _removeRecord(record);
        });
      } else {
        _removeRecord(record);
      }
    }
  }
}

class _BloomToastItemWidget extends StatefulWidget {
  final BloomToastAlignment alignment;
  final ValueNotifier<int> indexListenable;
  final VoidCallback onDismissRequest;
  final Widget child;

  const _BloomToastItemWidget({
    super.key,
    required this.alignment,
    required this.indexListenable,
    required this.onDismissRequest,
    required this.onDisposed,
    required this.child,
  });

  /// Called when this toast leaves the tree, so the host can cancel any
  /// pending auto-dismiss timer and release its record.
  final VoidCallback onDisposed;

  @override
  State<_BloomToastItemWidget> createState() => _BloomToastItemWidgetState();
}

class _BloomToastItemWidgetState extends State<_BloomToastItemWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  Future<void> animateOut() async {
    if (mounted) {
      await _controller.reverse();
    }
  }

  @override
  void dispose() {
    widget.onDisposed();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTop = widget.alignment == BloomToastAlignment.topLeft ||
        widget.alignment == BloomToastAlignment.topCenter ||
        widget.alignment == BloomToastAlignment.topRight;

    final Alignment boxAlignment = switch (widget.alignment) {
      BloomToastAlignment.topLeft => Alignment.topLeft,
      BloomToastAlignment.topCenter => Alignment.topCenter,
      BloomToastAlignment.topRight => Alignment.topRight,
      BloomToastAlignment.bottomLeft => Alignment.bottomLeft,
      BloomToastAlignment.bottomCenter => Alignment.bottomCenter,
      BloomToastAlignment.bottomRight => Alignment.bottomRight,
    };

    return ValueListenableBuilder<int>(
      valueListenable: widget.indexListenable,
      builder: (BuildContext context, int stackIndex, Widget? staticChild) {
        final double stackOffset = stackIndex * 58.0;

        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: SafeArea(
              child: Align(
                alignment: boxAlignment,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: isTop ? 16.0 + stackOffset : 16.0,
                    bottom: !isTop ? 16.0 + stackOffset : 16.0,
                    left: 16.0,
                    right: 16.0,
                  ),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? animChild) {
                      final double slide = isTop ? -_slideAnimation.value : _slideAnimation.value;
                      return Opacity(
                        opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, slide),
                          child: animChild,
                        ),
                      );
                    },
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
