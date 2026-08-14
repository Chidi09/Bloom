// lib/src/primitives/attachment.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

enum BloomAttachmentOrientation {
  horizontal,
  vertical,
}

enum BloomAttachmentSize {
  defaultSize,
  sm,
  xs,
}

class BloomAttachment extends StatelessWidget {
  final Widget? media;
  final String? title;
  final String? description;
  final String? sizeInfo;
  final List<Widget> actions;
  final BloomAttachmentOrientation orientation;
  final BloomAttachmentSize size;
  final VoidCallback? onTap;

  const BloomAttachment({
    super.key,
    this.media,
    this.title,
    this.description,
    this.sizeInfo,
    this.actions = const [],
    this.orientation = BloomAttachmentOrientation.horizontal,
    this.size = BloomAttachmentSize.defaultSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.bloomTheme;
    final colors = theme.colors;
    final radius = theme.radius;
    final dims = _resolveDimensions(size);

    final card = Container(
      padding: dims.padding,
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: colors.border),
      ),
      child: orientation == BloomAttachmentOrientation.horizontal
          ? Row(children: _buildChildren(context, dims))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildChildren(context, dims)),
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        child: GestureDetector(onTap: onTap, child: card),
      );
    }
    return card;
  }

  List<Widget> _buildChildren(BuildContext context, _AttachmentDimensions dims) {
    final theme = context.bloomTheme;
    final colors = theme.colors;

    return [
      if (media != null)
        Padding(
          padding: EdgeInsets.only(
            right: orientation == BloomAttachmentOrientation.horizontal ? dims.gap : 0,
            bottom: orientation == BloomAttachmentOrientation.vertical ? dims.gap : 0,
          ),
          child: SizedBox(
            width: dims.mediaSize,
            height: dims.mediaSize,
            child: media!,
          ),
        ),
      Expanded(
        child: Column(
          crossAxisAlignment: orientation == BloomAttachmentOrientation.horizontal
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title!,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: dims.titleSize,
                  fontWeight: FontWeight.w600,
                  fontFamily: theme.typography.sans,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (description != null)
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  description!,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: dims.descSize,
                    fontFamily: theme.typography.sans,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (sizeInfo != null)
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  sizeInfo!,
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: dims.descSize,
                    fontFamily: theme.typography.sans,
                  ),
                ),
              ),
          ],
        ),
      ),
      if (actions.isNotEmpty) ...[
        SizedBox(width: dims.gap),
        Row(mainAxisSize: MainAxisSize.min, children: actions),
      ],
    ];
  }

  static _AttachmentDimensions _resolveDimensions(BloomAttachmentSize size) {
    switch (size) {
      case BloomAttachmentSize.defaultSize:
        return const _AttachmentDimensions(
          padding: EdgeInsets.all(12),
          gap: 12,
          mediaSize: 40,
          titleSize: 14,
          descSize: 12,
        );
      case BloomAttachmentSize.sm:
        return const _AttachmentDimensions(
          padding: EdgeInsets.all(10),
          gap: 10,
          mediaSize: 32,
          titleSize: 13,
          descSize: 11,
        );
      case BloomAttachmentSize.xs:
        return const _AttachmentDimensions(
          padding: EdgeInsets.all(8),
          gap: 8,
          mediaSize: 24,
          titleSize: 12,
          descSize: 10,
        );
    }
  }
}

class _AttachmentDimensions {
  final EdgeInsetsGeometry padding;
  final double gap;
  final double mediaSize;
  final double titleSize;
  final double descSize;
  const _AttachmentDimensions({
    required this.padding,
    required this.gap,
    required this.mediaSize,
    required this.titleSize,
    required this.descSize,
  });
}

class BloomAttachmentGroup extends StatelessWidget {
  final List<BloomAttachment> attachments;
  final double spacing;

  const BloomAttachmentGroup({
    super.key,
    required this.attachments,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(attachments.length, (i) {
          return Padding(
            padding: EdgeInsets.only(left: i > 0 ? spacing : 0),
            child: SizedBox(
              width: 280,
              child: attachments[i],
            ),
          );
        }),
      ),
    );
  }
}

class BloomAttachmentTrigger extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BloomAttachmentTrigger({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.bloomRadius.md),
            border: Border.all(color: context.bloomColors.border, width: 1.5),
          ),
          padding: const EdgeInsets.all(8),
          child: child,
        ),
      ),
    );
  }
}
