// lib/src/primitives/marker.dart
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/extensions.dart';

enum BloomMarkerVariant {
  defaultVariant,
  separator,
  border,
}

/// Highlight marker component matching shadcn/ui base-nova.
class BloomMarker extends StatelessWidget {
  final BloomMarkerVariant variant;
  final Widget? icon;
  final Widget? content;
  final Widget? child;
  final VoidCallback? onTap;

  const BloomMarker({
    super.key,
    this.variant = BloomMarkerVariant.defaultVariant,
    this.icon,
    this.content,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    final markerWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: variant == BloomMarkerVariant.defaultVariant
            ? colors.surface2
            : BloomColors.transparent,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: variant == BloomMarkerVariant.border
            ? Border.all(color: colors.border)
            : null,
      ),
      child: child ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                IconTheme(
                  data: IconThemeData(color: colors.textSecondary, size: 14),
                  child: icon!,
                ),
                const SizedBox(width: 6),
              ],
              if (content != null)
                DefaultTextStyle(
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: context.bloomTypography.sans,
                  ),
                  child: content!,
                ),
            ],
          ),
    );

    if (onTap != null) {
      return BloomPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        child: markerWidget,
      );
    }

    return markerWidget;
  }
}

class BloomMarkerIcon extends StatelessWidget {
  final Widget child;
  const BloomMarkerIcon({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

class BloomMarkerContent extends StatelessWidget {
  final Widget child;
  const BloomMarkerContent({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
