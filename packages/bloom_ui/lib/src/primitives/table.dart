// lib/src/primitives/table.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomTableCell extends StatelessWidget {
  final Widget child;
  final bool isHeader;
  final EdgeInsetsGeometry? padding;

  const BloomTableCell({
    super.key,
    required this.child,
    this.isHeader = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DefaultTextStyle(
        style: TextStyle(
          color: isHeader ? colors.textSecondary : colors.textPrimary,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          fontSize: isHeader ? 13 : 14,
          fontFamily: context.bloomTypography.sans,
        ),
        child: child,
      ),
    );
  }
}

class BloomTableRow extends StatelessWidget {
  final List<BloomTableCell> cells;
  final bool isHeader;
  final VoidCallback? onTap;

  const BloomTableRow({
    super.key,
    required this.cells,
    this.isHeader = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    final row = Container(
      decoration: BoxDecoration(
        color: isHeader ? colors.surface2 : Colors.transparent,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: cells.map((c) => Expanded(child: c)).toList(),
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: row);
    }
    return row;
  }
}

class BloomTable extends StatelessWidget {
  final List<BloomTableRow> rows;

  const BloomTable({
    super.key,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}
