// lib/src/primitives/tabs.dart
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

/// Visual style variant for [BloomTabs].
enum BloomTabsVariant {
  /// Segmented pill-style tab list container with an elevated active tab indicator.
  defaultVariant,

  /// Underlined tab list where the active tab has a colored bottom border highlight.
  line,
}

/// Represents an individual tab item within a [BloomTabs] container.
///
/// Holds the identifier [value], the header [label], the [content] widget
/// to render when active, and an optional leading [icon].
class BloomTabItem<T> {
  /// The unique value identifying this tab.
  final T value;

  /// The widget displayed in the tab trigger bar (typically a [Text] widget).
  final Widget label;

  /// The widget content rendered in the tab view body when this tab is selected.
  final Widget content;

  /// An optional leading icon displayed beside the [label] in the tab trigger bar.
  final Widget? icon;

  /// Creates a [BloomTabItem] configuration.
  ///
  /// The [value], [label], and [content] parameters are required.
  const BloomTabItem({
    required this.value,
    required this.label,
    required this.content,
    this.icon,
  });
}

/// A versatile tabbed navigation container matching shadcn base-nova aesthetics.
///
/// Renders a list of tab triggers at the top and switches the active content view
/// below based on the currently selected tab.
///
/// Supports both controlled (via [value] and [onChanged]) and uncontrolled
/// (via [defaultValue]) modes of operation.
///
/// ```dart
/// BloomTabs<String>(
///   defaultValue: 'account',
///   items: [
///     BloomTabItem(
///       value: 'account',
///       label: Text('Account'),
///       icon: BloomIcon(BloomIcons.person),
///       content: Text('Account Settings'),
///     ),
///     BloomTabItem(
///       value: 'password',
///       label: Text('Password'),
///       icon: BloomIcon(BloomIcons.lock),
///       content: Text('Password Settings'),
///     ),
///   ],
/// )
/// ```
class BloomTabs<T> extends StatefulWidget {
  /// The list of tab items containing their identifier, label, and body content.
  final List<BloomTabItem<T>> items;

  /// The currently active tab value when used as a controlled component.
  ///
  /// When provided, updates to the selected tab must be driven externally through [onChanged].
  final T? value;

  /// The initial tab value selected on first render when uncontrolled.
  final T defaultValue;

  /// Callback invoked when the user selects a different tab.
  final ValueChanged<T>? onChanged;

  /// The visual style of the tab trigger header.
  ///
  /// Defaults to [BloomTabsVariant.defaultVariant].
  final BloomTabsVariant variant;

  /// Layout axis for tab arrangement.
  ///
  /// Defaults to [Axis.horizontal].
  final Axis orientation;

  /// Creates a [BloomTabs] component.
  ///
  /// Requires [items] and [defaultValue].
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
            return BloomPressable(
              onTap: () => _select(item.value),
              borderRadius: BorderRadius.circular(theme.radius.sm),
              child: AnimatedContainer(
                duration: BloomMotion.instant,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? colors.surface1 : BloomColors.transparent,
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
            return BloomPressable(
              onTap: () => _select(item.value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? colors.primary : BloomColors.transparent,
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
