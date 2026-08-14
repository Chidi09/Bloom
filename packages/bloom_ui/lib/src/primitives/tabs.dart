// lib/src/primitives/tabs.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

enum BloomTabsVariant { defaultVariant, line }

class BloomTabItem<T> {
  final T value;
  final Widget label;
  final Widget content;
  final Widget? icon;

  const BloomTabItem({
    required this.value,
    required this.label,
    required this.content,
    this.icon,
  });
}

/// Tab navigation container matching shadcn base-nova.
class BloomTabs<T> extends StatefulWidget {
  final List<BloomTabItem<T>> items;
  final T? value;
  final T defaultValue;
  final ValueChanged<T>? onChanged;
  final BloomTabsVariant variant;
  final Axis orientation;

  const BloomTabs({
    super.key,
    required this.items,
    this.value,
    required this.defaultValue,
    this.onChanged,
    this.variant = BloomTabsVariant.defaultVariant,
    this.orientation = Axis.horizontal,
  });

  @override
  State<BloomTabs<T>> createState() => _BloomTabsState<T>();
}

class _BloomTabsState<T> extends State<BloomTabs<T>> {
  late BloomControllableValue<T> _state;

  @override
  void initState() {
    super.initState();
    _state = BloomControllableValue<T>(
      controlledValue: widget.value,
      defaultValue: widget.defaultValue,
      onChanged: widget.onChanged,
    );
  }

  @override
  void didUpdateWidget(covariant BloomTabs<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _state = BloomControllableValue<T>(
        controlledValue: widget.value,
        defaultValue: widget.defaultValue,
        onChanged: widget.onChanged,
      );
    }
  }

  void _select(T value) {
    setState(() => _state.update(value));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;
    final selected = _state.value;

    final activeItem = widget.items.firstWhere(
      (item) => item.value == selected,
      orElse: () => widget.items.first,
    );

    Widget header;
    if (widget.variant == BloomTabsVariant.defaultVariant) {
      header = Container(
        height: 32, // h-8
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surface0, // bg-muted
          borderRadius: BorderRadius.circular(theme.radius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: widget.items.map((item) {
            final isSelected = item.value == selected;
            return InkWell(
              onTap: () => _select(item.value),
              borderRadius: BorderRadius.circular(theme.radius.sm),
              child: AnimatedContainer(
                duration: BloomMotion.instant,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? colors.surface1 : Colors.transparent,
                  borderRadius: BorderRadius.circular(theme.radius.sm),
                  boxShadow: isSelected ? const [BloomShadows.s1] : null,
                ),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: isSelected ? colors.textPrimary : colors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontFamily: theme.typography.sans,
                    letterSpacing: -0.1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.icon != null) ...[
                        IconTheme(
                          data: IconThemeData(
                            color: isSelected ? colors.textPrimary : colors.textSecondary,
                            size: 14,
                          ),
                          child: item.icon!,
                        ),
                        const SizedBox(width: 6),
                      ],
                      item.label,
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    } else {
      // Line variant
      header = Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: widget.items.map((item) {
            final isSelected = item.value == selected;
            return InkWell(
              onTap: () => _select(item.value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? colors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: isSelected ? colors.textPrimary : colors.textSecondary,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontFamily: theme.typography.sans,
                  ),
                  child: item.label,
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        const SizedBox(height: 12),
        activeItem.content,
      ],
    );
  }
}
