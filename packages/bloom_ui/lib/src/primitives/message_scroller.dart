// lib/src/primitives/message_scroller.dart
import 'package:flutter/widgets.dart';
import '../icons/bloom_icon.dart';
import '../icons/bloom_icons.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/bloom_surface.dart';
import '../utils/extensions.dart';

/// An auto-scrolling container optimized for chat and conversation threads.
///
/// Features automated stick-to-bottom behavior when new messages arrive, a smooth scroll button
/// to jump back to latest messages, and reverse scrolling support.
///
/// Example:
/// ```dart
/// BloomMessageScroller(
///   items: [
///     BloomMessage(content: Text('Hello')),
///     BloomMessage(content: Text('Hi there!')),
///   ],
///   enableAutoScroll: true,
/// )
/// ```
class BloomMessageScroller extends StatefulWidget {
  /// The list of message or item widgets to display.
  final List<Widget> items;

  /// Whether to automatically scroll to the bottom/newest message when items are added. Defaults to true.
  final bool enableAutoScroll;

  /// Whether the scroll view is reversed (newest items at top). Defaults to false.
  final bool reverse;

  /// Distance threshold in pixels near the edge where auto-scroll remains active. Defaults to 50.
  final double scrollThresholdPx;

  /// Optional padding around the scrollable content. Defaults to 16.
  final EdgeInsetsGeometry? padding;

  /// Creates a [BloomMessageScroller].
  const BloomMessageScroller({
    super.key,
    required this.items,
    this.enableAutoScroll = true,
    this.reverse = false,
    this.scrollThresholdPx = 50,
    this.padding,
  });

  @override
  State<BloomMessageScroller> createState() => _BloomMessageScrollerState();
}

class _BloomMessageScrollerState extends State<BloomMessageScroller> {
  final ScrollController _scrollController = ScrollController();
  bool _showButton = false;

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    return (max - current) <= widget.scrollThresholdPx;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant BloomMessageScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    final added = widget.items.length > oldWidget.items.length;
    if (added && widget.enableAutoScroll) {
      final addedCount = widget.items.length - oldWidget.items.length;
      if (_isNearBottom || widget.reverse) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.animateTo(
              widget.reverse ? 0 : _scrollController.position.maxScrollExtent,
              duration: BloomMotion.base,
              curve: BloomMotion.easeOut,
            );
          }
        });
      } else if (widget.reverse && addedCount == 1) {
        final offsetDelta = _estimateItemHeight() * addedCount;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(
              (_scrollController.position.pixels + offsetDelta)
                  .clamp(0.0, _scrollController.position.maxScrollExtent),
            );
          }
        });
      }
    }
  }

  double _estimateItemHeight() {
    return 60.0;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = widget.reverse
        ? _scrollController.position.pixels > widget.scrollThresholdPx
        : !_isNearBottom;
    if (show != _showButton) {
      setState(() => _showButton = show);
    }
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      widget.reverse ? 0 : _scrollController.position.maxScrollExtent,
      duration: BloomMotion.base,
      curve: BloomMotion.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.surface1,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(theme.radius.md),
          ),
          clipBehavior: Clip.antiAlias,
          child: RawScrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: widget.padding ?? const EdgeInsets.all(16),
              child: BloomMessageScrollerContent(
                reverse: widget.reverse,
                items: widget.items,
              ),
            ),
          ),
        ),
        if (_showButton)
          Positioned(
            bottom: widget.reverse ? null : 16,
            top: widget.reverse ? 16 : null,
            right: 16,
            child: BloomMessageScrollerButton(
              onPressed: _scrollToEnd,
              isReverse: widget.reverse,
            ),
          ),
      ],
    );
  }
}

/// The inner content column managing item layout and ordering for [BloomMessageScroller].
class BloomMessageScrollerContent extends StatelessWidget {
  /// Whether the display order is reversed.
  final bool reverse;

  /// The list of item widgets.
  final List<Widget> items;

  /// Creates a [BloomMessageScrollerContent].
  const BloomMessageScrollerContent({
    super.key,
    required this.reverse,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final children = List<Widget>.generate(items.length, (i) {
      return BloomMessageScrollerItem(
        isLast: i == items.length - 1,
        child: items[i],
      );
    });

    final ordered = reverse ? children.reversed.toList() : children;

    return Column(
      children: ordered,
    );
  }
}

/// A wrapper item in [BloomMessageScroller] with standardized spacing.
class BloomMessageScrollerItem extends StatelessWidget {
  /// The child message widget.
  final Widget child;

  /// Whether this is the final item in the list (removes bottom spacing). Defaults to false.
  final bool isLast;

  /// Creates a [BloomMessageScrollerItem].
  const BloomMessageScrollerItem({
    super.key,
    required this.child,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: child,
    );
  }
}

/// Floating action button that scrolls the [BloomMessageScroller] back to the latest message.
class BloomMessageScrollerButton extends StatelessWidget {
  /// Callback fired when the scroll button is pressed.
  final VoidCallback onPressed;

  /// Whether the scroll view is reversed, determining arrow icon direction. Defaults to false.
  final bool isReverse;

  /// Creates a [BloomMessageScrollerButton].
  const BloomMessageScrollerButton({
    super.key,
    required this.onPressed,
    this.isReverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return AnimatedOpacity(
      duration: BloomMotion.fast,
      opacity: 1,
      child: AnimatedScale(
        duration: BloomMotion.fast,
        scale: 1,
        child: BloomSurface(
          color: colors.secondary,
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          child: BloomPressable(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: BloomIcon(
                isReverse ? BloomIcons.arrowUpward : BloomIcons.arrowDownward,
                color: colors.secondaryForeground,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
