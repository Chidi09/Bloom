// lib/src/primitives/pagination.dart
import 'package:flutter/material.dart';
import 'button.dart';

class BloomPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const BloomPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BloomButton(
          size: BloomButtonSize.sm,
          variant: BloomButtonVariant.outline,
          disabled: currentPage <= 1,
          onPressed: () => onPageChanged(currentPage - 1),
          child: const Text('Previous'),
        ),
        const SizedBox(width: 8),
        ...List.generate(totalPages, (index) {
          final page = index + 1;
          final isCurrent = page == currentPage;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: SizedBox(
              width: 36,
              height: 36,
              child: BloomButton(
                size: BloomButtonSize.sm,
                variant: isCurrent ? BloomButtonVariant.defaultVariant : BloomButtonVariant.ghost,
                onPressed: () => onPageChanged(page),
                child: Text('$page'),
              ),
            ),
          );
        }),
        const SizedBox(width: 8),
        BloomButton(
          size: BloomButtonSize.sm,
          variant: BloomButtonVariant.outline,
          disabled: currentPage >= totalPages,
          onPressed: () => onPageChanged(currentPage + 1),
          child: const Text('Next'),
        ),
      ],
    );
  }
}
