// lib/src/primitives/pagination.dart
import 'package:flutter/widgets.dart';
import '../icons/bloom_icon.dart';
import '../icons/bloom_icons.dart';
import '../utils/extensions.dart';
import 'button.dart';

/// Page number pagination navigation matching shadcn base-nova.
class BloomPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int visiblePageCount;

  const BloomPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.visiblePageCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    final canGoPrev = currentPage > 1;
    final canGoNext = currentPage < totalPages;

    List<int> pages = [];
    int start = (currentPage - visiblePageCount ~/ 2).clamp(1, totalPages);
    int end = (start + visiblePageCount - 1).clamp(1, totalPages);
    if (end - start + 1 < visiblePageCount) {
      start = (end - visiblePageCount + 1).clamp(1, totalPages);
    }
    for (int i = start; i <= end; i++) {
      pages.add(i);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BloomButton(
          variant: BloomButtonVariant.outline,
          size: BloomButtonSize.sm,
          disabled: !canGoPrev,
          onPressed: canGoPrev ? () => onPageChanged(currentPage - 1) : null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BloomIcon(BloomIcons.chevronLeft, size: 14),
              SizedBox(width: 4),
              Text('Previous'),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (start > 1) ...[
          _buildPageButton(context, 1),
          if (start > 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('...', style: TextStyle(color: colors.textTertiary)),
            ),
        ],
        for (final p in pages) _buildPageButton(context, p),
        if (end < totalPages) ...[
          if (end < totalPages - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('...', style: TextStyle(color: colors.textTertiary)),
            ),
          _buildPageButton(context, totalPages),
        ],
        const SizedBox(width: 6),
        BloomButton(
          variant: BloomButtonVariant.outline,
          size: BloomButtonSize.sm,
          disabled: !canGoNext,
          onPressed: canGoNext ? () => onPageChanged(currentPage + 1) : null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Next'),
              SizedBox(width: 4),
              BloomIcon(BloomIcons.chevronRight, size: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageButton(BuildContext context, int page) {
    final isCurrent = page == currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: BloomButton(
        variant: isCurrent ? BloomButtonVariant.defaultVariant : BloomButtonVariant.ghost,
        size: BloomButtonSize.iconSm, // 28x28px
        onPressed: () => onPageChanged(page),
        child: Text('$page'),
      ),
    );
  }
}

class BloomPaginationNext extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool disabled;
  const BloomPaginationNext({super.key, this.onPressed, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return BloomButton(
      variant: BloomButtonVariant.outline,
      size: BloomButtonSize.sm,
      disabled: disabled,
      onPressed: onPressed,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Next'),
          SizedBox(width: 4),
          BloomIcon(BloomIcons.chevronRight, size: 14),
        ],
      ),
    );
  }
}

class BloomPaginationPrevious extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool disabled;
  const BloomPaginationPrevious({super.key, this.onPressed, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return BloomButton(
      variant: BloomButtonVariant.outline,
      size: BloomButtonSize.sm,
      disabled: disabled,
      onPressed: onPressed,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BloomIcon(BloomIcons.chevronLeft, size: 14),
          SizedBox(width: 4),
          Text('Previous'),
        ],
      ),
    );
  }
}

class BloomPaginationEllipsis extends StatelessWidget {
  const BloomPaginationEllipsis({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: BloomIcon(BloomIcons.moreHorizontal, size: 14, color: context.bloomColors.textTertiary),
    );
  }
}
