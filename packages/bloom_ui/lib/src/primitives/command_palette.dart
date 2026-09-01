// lib/src/primitives/command_palette.dart
import 'package:flutter/widgets.dart';
import '../icons/bloom_icon.dart';
import '../icons/bloom_icons.dart';
import '../utils/bloom_editable_field.dart';
import '../utils/bloom_modal_routes.dart';
import '../utils/bloom_pressable.dart';
import '../utils/bloom_surface.dart';
import '../utils/extensions.dart';
import 'separator.dart';

/// A selectable action or search result entry in a [BloomCommandPalette].
///
/// Example:
/// ```dart
/// BloomCommandItem(
///   title: 'Open Settings',
///   subtitle: 'Configure application preferences',
///   icon: BloomIcon(BloomIcons.settings),
///   shortcut: 'Cmd+,',
///   onSelected: () => openSettings(),
/// )
/// ```
class BloomCommandItem {
  /// The main display title of the command.
  final String title;

  /// Optional subtitle or helper description.
  final String? subtitle;

  /// Optional leading icon widget.
  final Widget? icon;

  /// Optional keyboard shortcut label (e.g., `'Cmd+K'`).
  final String? shortcut;

  /// Whether a checkmark is shown indicating active or selected state. Defaults to false.
  final bool isChecked;

  /// Callback executed when the user activates this command.
  final VoidCallback onSelected;

  /// Creates a [BloomCommandItem].
  const BloomCommandItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.shortcut,
    this.isChecked = false,
    required this.onSelected,
  });
}

/// A logical grouping of [BloomCommandItem] entries with an optional heading.
class BloomCommandGroup {
  /// Optional section header label.
  final String? heading;

  /// The list of command items belonging to this group.
  final List<BloomCommandItem> items;

  /// Creates a [BloomCommandGroup].
  const BloomCommandGroup({
    this.heading,
    required this.items,
  });
}

/// A badge-like pill indicating a keyboard shortcut in command palette items.
///
/// Example:
/// ```dart
/// BloomCommandShortcut('Ctrl+P')
/// ```
class BloomCommandShortcut extends StatelessWidget {
  /// The keyboard shortcut string to render (e.g. `'Cmd+K'`).
  final String keys;

  /// Creates a [BloomCommandShortcut].
  const BloomCommandShortcut(this.keys, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.secondary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        keys,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: context.bloomTypography.mono,
        ),
      ),
    );
  }
}

/// A modal command menu / quick-search dialog matching modern command palette interfaces.
///
/// Example:
/// ```dart
/// BloomCommandPalette.show(
///   context: context,
///   items: [
///     BloomCommandItem(
///       title: 'New File',
///       shortcut: 'Cmd+N',
///       onSelected: () => createNewFile(),
///     ),
///   ],
/// );
/// ```
class BloomCommandPalette extends StatefulWidget {
  /// List of ungrouped command items to search and display.
  final List<BloomCommandItem> items;

  /// Optional grouped command items. If provided, overrides [items].
  final List<BloomCommandGroup>? groups;

  /// Search input placeholder text. Defaults to `'Type a command or search...'`.
  final String placeholder;

  /// Creates a [BloomCommandPalette].
  const BloomCommandPalette({
    super.key,
    this.items = const [],
    this.groups,
    this.placeholder = 'Type a command or search...',
  });

  /// Displays the [BloomCommandPalette] as a modal dialog.
  static Future<void> show({
    required BuildContext context,
    List<BloomCommandItem> items = const [],
    List<BloomCommandGroup>? groups,
    String placeholder = 'Type a command or search...',
  }) {
    return showBloomDialog<void>(
      context: context,
      builder: (context) => BloomCommandPalette(
        items: items,
        groups: groups,
        placeholder: placeholder,
      ),
    );
  }

  @override
  State<BloomCommandPalette> createState() => _BloomCommandPaletteState();
}

class _BloomCommandPaletteState extends State<BloomCommandPalette> {
  final TextEditingController _query = TextEditingController();
  List<BloomCommandItem> _allItems = [];
  List<BloomCommandItem> _filtered = [];

  @override
  void initState() {
    super.initState();
    _rebuildItemList();
  }

  void _rebuildItemList() {
    if (widget.groups != null && widget.groups!.isNotEmpty) {
      _allItems = widget.groups!.expand((g) => g.items).toList();
    } else {
      _allItems = widget.items;
    }
    _filtered = _allItems;
  }

  void _onQuery(String val) {
    setState(() {
      if (val.trim().isEmpty) {
        _filtered = _allItems;
      } else {
        final q = val.toLowerCase();
        _filtered = _allItems.where((i) {
          return i.title.toLowerCase().contains(q) ||
              (i.subtitle?.toLowerCase().contains(q) ?? false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500,
            maxHeight: 400,
          ),
          child: BloomSurface(
            elevation: 8,
            borderRadius: BorderRadius.circular(context.bloomRadius.lg),
            color: colors.surface1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.bloomRadius.lg),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search Input
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        BloomIcon(BloomIcons.search, size: 20, color: colors.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BloomEditableField(
                            controller: _query,
                            autofocus: true,
                            placeholder: widget.placeholder,
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                            decoration: const BoxDecoration(),
                            onChanged: _onQuery,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const BloomSeparator(thickness: 1),
                  // Results list
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No results found.',
                              style: TextStyle(color: colors.textSecondary, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final item = _filtered[index];
                              return BloomPressable(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  item.onSelected();
                                },
                                borderRadius: BorderRadius.circular(context.bloomRadius.md),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      if (item.icon != null) ...[
                                        item.icon!,
                                        const SizedBox(width: 12),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                fontFamily: context.bloomTypography.sans,
                                              ),
                                            ),
                                            if (item.subtitle != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                item.subtitle!,
                                                style: TextStyle(
                                                  color: colors.textSecondary,
                                                  fontSize: 12,
                                                  fontFamily: context.bloomTypography.sans,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (item.shortcut != null) ...[
                                        const SizedBox(width: 8),
                                        BloomCommandShortcut(item.shortcut!),
                                      ],
                                      if (item.isChecked) ...[
                                        const SizedBox(width: 8),
                                        BloomIcon(BloomIcons.check, size: 16, color: colors.primary),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

