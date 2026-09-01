// lib/src/primitives/label.dart
import 'package:flutter/widgets.dart';
import '../utils/extensions.dart';

class BloomLabel extends StatelessWidget {
  final String text;
  final bool required;
  final Widget? trailing;

  const BloomLabel(
    this.text, {
    super.key,
    this.required = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: context.bloomColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: context.bloomTypography.sans,
            ),
          ),
          if (required) ...[
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: context.bloomColors.error,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
