// lib/src/primitives/error_state.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'button.dart';

class BloomErrorState extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onRetry;
  final String retryText;

  const BloomErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.description,
    this.onRetry,
    this.retryText = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 36, color: colors.error),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: context.bloomTypography.sans,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                fontFamily: context.bloomTypography.sans,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              BloomButton(
                variant: BloomButtonVariant.outline,
                onPressed: onRetry,
                child: Text(retryText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
