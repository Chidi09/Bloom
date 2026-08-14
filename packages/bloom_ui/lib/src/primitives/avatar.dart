// lib/src/primitives/avatar.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

enum BloomAvatarSize {
  defaultSize, // 32x32px (size-8)
  sm,          // 24x24px (size-6)
  lg,          // 40x40px (size-10)
}

/// User avatar matching shadcn base-nova dimensions and fallback monogram support.
class BloomAvatar extends StatelessWidget {
  final ImageProvider? image;
  final String? name;
  final BloomAvatarSize size;
  final Widget? badge;
  final Widget? fallback;

  const BloomAvatar({
    super.key,
    this.image,
    this.name,
    this.size = BloomAvatarSize.defaultSize,
    this.badge,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final dim = _resolveDimension(size);

    String monogram = '';
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.length >= 2) {
        monogram = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        monogram = name![0].toUpperCase();
      }
    }

    final avatarCircle = Container(
      width: dim,
      height: dim,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface0, // bg-muted
        image: image != null ? DecorationImage(image: image!, fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: image == null
          ? (fallback ??
              Text(
                monogram,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: dim * 0.4,
                  fontWeight: FontWeight.w600,
                  fontFamily: context.bloomTypography.sans,
                ),
              ))
          : null,
    );

    if (badge != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          avatarCircle,
          Positioned(
            right: 0,
            bottom: 0,
            child: badge!,
          ),
        ],
      );
    }

    return avatarCircle;
  }

  double _resolveDimension(BloomAvatarSize size) {
    switch (size) {
      case BloomAvatarSize.sm:
        return 24.0;
      case BloomAvatarSize.defaultSize:
        return 32.0;
      case BloomAvatarSize.lg:
        return 40.0;
    }
  }
}

/// Overlapping group of user avatars
class BloomAvatarGroup extends StatelessWidget {
  final List<Widget> children;
  final double overlap;

  const BloomAvatarGroup({
    super.key,
    required this.children,
    this.overlap = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(children.length, (i) {
        return Padding(
          padding: EdgeInsets.only(left: i > 0 ? -overlap : 0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.bloomColors.surface1, width: 2),
            ),
            child: children[i],
          ),
        );
      }),
    );
  }
}
