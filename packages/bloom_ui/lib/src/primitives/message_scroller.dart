// lib/src/primitives/message_scroller.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomMessageScroller extends StatefulWidget {
  final List<Widget> items;
  final bool enableAutoScroll;
  final bool reverse;
  final double scrollThresholdPx;
  final EdgeInsetsGeometry? padding;

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
          child: Scrollbar(
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

class BloomMessageScrollerContent extends StatelessWidget {
  final bool reverse;
  final List<Widget> items;

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

class BloomMessageScrollerItem extends StatelessWidget {
  final Widget child;
  final bool isLast;

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

class BloomMessageScrollerButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isReverse;

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
        child: Material(
          color: colors.secondary,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                isReverse ? Icons.arrow_upward : Icons.arrow_downward,
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
