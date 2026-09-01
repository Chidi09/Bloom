// lib/src/primitives/banner.dart
import 'package:flutter/widgets.dart';
import '../utils/extensions.dart';

class BloomBanner extends StatelessWidget {
  final String message;
  final Widget? leading;
  final List<Widget>? actions;

  const BloomBanner({
    super.key,
    required this.message,
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: 12),
            Row(mainAxisSize: MainAxisSize.min, children: actions!),
          ],
        ],
      ),
    );
  }
}
