// lib/src/primitives/table.dart
import 'package:flutter/widgets.dart';
import '../utils/extensions.dart';

/// Structured data table container matching shadcn base-nova.
class BloomTable extends StatelessWidget {
  final Widget? header;
  final Widget? body;
  final Widget? footer;
  final Widget? caption;
  final List<TableRow>? rows;

  const BloomTable({
    super.key,
    this.header,
    this.body,
    this.footer,
    this.caption,
    this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    if (rows != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          border: Border.all(color: colors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(horizontalInside: BorderSide(color: colors.border)),
            children: rows!,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) header!,
            if (body != null) body!,
            if (footer != null) footer!,
            if (caption != null) caption!,
          ],
        ),
      ),
    );
  }
}

/// Table column header cell
class BloomTableHead extends StatelessWidget {
  final Widget child;
  final TextAlign textAlign;

  const BloomTableHead({
    super.key,
    required this.child,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40, // h-10
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: context.bloomColors.surface0,
      alignment: Alignment.centerLeft,
      child: DefaultTextStyle(
        style: TextStyle(
          color: context.bloomColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: context.bloomTypography.sans,
        ),
        child: child,
      ),
    );
  }
}

/// Table body cell
class BloomTableCell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BloomTableCell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // p-2.5
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: DefaultTextStyle(
        style: TextStyle(
          color: context.bloomColors.textPrimary,
          fontSize: 13.5,
          fontFamily: context.bloomTypography.sans,
        ),
        child: child,
      ),
    );
  }
}
