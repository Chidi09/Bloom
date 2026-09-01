// lib/src/primitives/sidebar.dart
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/extensions.dart';

/// Composable collapsible sidebar matching shadcn/ui base-nova.
class BloomSidebar extends StatelessWidget {
  final Widget? header;
  final Widget? content;
  final Widget? footer;
  final Widget? child;
  final double width;
  final bool collapsed;

  const BloomSidebar({
    super.key,
    this.header,
    this.content,
    this.footer,
    this.child,
    this.width = 240,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return AnimatedContainer(
      duration: BloomMotion.fast,
      width: collapsed ? 56 : width,
      decoration: BoxDecoration(
        color: colors.surface0,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: content ?? child ?? const SizedBox.shrink(),
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

class BloomSidebarHeader extends StatelessWidget {
  final Widget child;
  const BloomSidebarHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.bloomColors.border)),
      ),
      child: child,
    );
  }
}

class BloomSidebarFooter extends StatelessWidget {
  final Widget child;
  const BloomSidebarFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.bloomColors.border)),
      ),
      child: child,
    );
  }
}

class BloomSidebarGroup extends StatelessWidget {
  final String? label;
  final List<Widget> children;

  const BloomSidebarGroup({super.key, this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                label!.toUpperCase(),
                style: TextStyle(
                  color: context.bloomColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: context.bloomTypography.sans,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class BloomSidebarMenuButton extends StatelessWidget {
  final Widget icon;
  final Widget label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isCurrent;

  const BloomSidebarMenuButton({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: BloomPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        child: Container(
          height: 32, // h-8
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isCurrent ? colors.surface1 : BloomColors.transparent,
            borderRadius: BorderRadius.circular(context.bloomRadius.md),
            border: isCurrent ? Border.all(color: colors.border.withValues(alpha: 0.5)) : null,
          ),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(
                  color: isCurrent ? colors.textPrimary : colors.textSecondary,
                  size: 16,
                ),
                child: icon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: isCurrent ? colors.textPrimary : colors.textSecondary,
                    fontSize: 13.5,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    fontFamily: context.bloomTypography.sans,
                  ),
                  child: label,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
