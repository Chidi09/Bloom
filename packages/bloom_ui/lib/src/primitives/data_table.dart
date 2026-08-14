// lib/src/primitives/data_table.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomDataColumn<T> {
  final String label;
  final Widget Function(T item) builder;
  final int flex;

  const BloomDataColumn({
    required this.label,
    required this.builder,
    this.flex = 1,
  });
}

class BloomDataTable<T> extends StatelessWidget {
  final List<BloomDataColumn<T>> columns;
  final List<T> data;
  final void Function(T item)? onRowTap;

  const BloomDataTable({
    super.key,
    required this.columns,
    required this.data,
    this.onRowTap,
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
      child: Column(
        children: [
          // Header
          Container(
            color: colors.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: columns.map((col) {
                return Expanded(
                  flex: col.flex,
                  child: Text(
                    col.label,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: context.bloomTypography.sans,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(height: 1, color: colors.border),
          // Rows
          ...data.map((item) {
            return InkWell(
              onTap: onRowTap != null ? () => onRowTap!(item) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: columns.map((col) {
                    return Expanded(
                      flex: col.flex,
                      child: col.builder(item),
                    );
                  }).toList(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
