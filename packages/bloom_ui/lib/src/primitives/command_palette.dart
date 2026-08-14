// lib/src/primitives/command_palette.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomCommandItem {
  final String title;
  final String? subtitle;
  final Widget? icon;
  final String? shortcut;
  final bool isChecked;
  final VoidCallback onSelected;

  const BloomCommandItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.shortcut,
    this.isChecked = false,
    required this.onSelected,
  });
}

class BloomCommandGroup {
  final String? heading;
  final List<BloomCommandItem> items;

  const BloomCommandGroup({
    this.heading,
    required this.items,
  });
}

class BloomCommandShortcut extends StatelessWidget {
  final String keys;

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

class BloomCommandPalette extends StatefulWidget {
  final List<BloomCommandItem> items;
  final List<BloomCommandGroup>? groups;
  final String placeholder;

  const BloomCommandPalette({
    super.key,
    this.items = const [],
    this.groups,
    this.placeholder = 'Type a command or search...',
  });

  static Future<void> show({
    required BuildContext context,
    List<BloomCommandItem> items = const [],
    List<BloomCommandGroup>? groups,
    String placeholder = 'Type a command or search...',
  }) {
    return showDialog(
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

    return Dialog(
      backgroundColor: colors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.bloomRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: colors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      onChanged: _onQuery,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontFamily: context.bloomTypography.sans,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: TextStyle(color: colors.textTertiary, fontSize: 15),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
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
                        return InkWell(
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
                                  Icon(Icons.check, size: 16, color: colors.primary),
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
    );
  }
}
