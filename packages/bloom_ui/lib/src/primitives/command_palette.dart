// lib/src/primitives/command_palette.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomCommandItem {
  final String title;
  final String? subtitle;
  final Widget? icon;
  final VoidCallback onSelected;

  const BloomCommandItem({
    required this.title,
    this.subtitle,
    this.icon,
    required this.onSelected,
  });
}

class BloomCommandPalette extends StatefulWidget {
  final List<BloomCommandItem> items;
  final String placeholder;

  const BloomCommandPalette({
    super.key,
    required this.items,
    this.placeholder = 'Type a command or search...',
  });

  static Future<void> show({
    required BuildContext context,
    required List<BloomCommandItem> items,
    String placeholder = 'Type a command or search...',
  }) {
    return showDialog(
      context: context,
      builder: (context) => BloomCommandPalette(
        items: items,
        placeholder: placeholder,
      ),
    );
  }

  @override
  State<BloomCommandPalette> createState() => _BloomCommandPaletteState();
}

class _BloomCommandPaletteState extends State<BloomCommandPalette> {
  final TextEditingController _query = TextEditingController();
  List<BloomCommandItem> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  void _onQuery(String val) {
    setState(() {
      if (val.trim().isEmpty) {
        _filtered = widget.items;
      } else {
        _filtered = widget.items.where((i) {
          final q = val.toLowerCase();
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
