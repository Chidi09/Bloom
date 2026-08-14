// lib/src/primitives/sheet.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomSheet extends StatelessWidget {
  final String? title;
  final String? description;
  final Widget child;

  const BloomSheet({
    super.key,
    this.title,
    this.description,
    required this.child,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? description,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BloomSheet(
        title: title,
        description: description,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.bloomRadius.xl)),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: 16),
            Text(
              title!,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
