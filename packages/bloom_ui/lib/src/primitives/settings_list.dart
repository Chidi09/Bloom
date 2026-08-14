// lib/src/primitives/settings_list.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomSettingsTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const BloomSettingsTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: context.bloomTypography.sans,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                fontFamily: context.bloomTypography.sans,
              ),
            )
          : null,
      trailing: trailing ?? Icon(Icons.chevron_right, size: 20, color: colors.textTertiary),
      onTap: onTap,
    );
  }
}

class BloomSettingsSection extends StatelessWidget {
  final String? title;
  final List<BloomSettingsTile> tiles;

  const BloomSettingsSection({
    super.key,
    this.title,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title!.toUpperCase(),
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(context.bloomRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: List.generate(tiles.length * 2 - 1, (index) {
              if (index.isOdd) {
                return Divider(height: 1, color: colors.border);
              }
              return tiles[index ~/ 2];
            }),
          ),
        ),
      ],
    );
  }
}

class BloomSettingsList extends StatelessWidget {
  final List<BloomSettingsSection> sections;

  const BloomSettingsList({
    super.key,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: sections.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: s,
      )).toList(),
    );
  }
}
