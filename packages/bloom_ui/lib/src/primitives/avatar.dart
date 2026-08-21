// lib/src/primitives/avatar.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Size variants for [BloomAvatar].
enum BloomAvatarSize {
  /// Default avatar size: 32x32px (size-8).
  defaultSize,

  /// Small avatar size: 24x24px (size-6).
  sm,

  /// Large avatar size: 40x40px (size-10).
  lg,
}

/// A user avatar matching shadcn base-nova dimensions and fallback monogram support.
///
/// Displays an image provided by [image], a monogram derived from [name], or a
/// custom [fallback] widget inside a circular surface container. Can also display
/// an optional status [badge] positioned at the bottom-right corner.
///
/// ```dart
/// BloomAvatar(
///   name: 'John Doe',
///   size: BloomAvatarSize.lg,
///   badge: Container(
///     width: 10,
///     height: 10,
///     decoration: const BoxDecoration(
///       color: Colors.green,
///       shape: BoxShape.circle,
///     ),
///   ),
/// );
/// ```
class BloomAvatar extends StatelessWidget {
  /// The image provider used to render the avatar graphic.
  final ImageProvider? image;

  /// The user's full name, from which a 1 or 2 letter monogram is automatically generated.
  final String? name;

  /// The size variant determining the avatar dimensions. Defaults to [BloomAvatarSize.defaultSize].
  final BloomAvatarSize size;

  /// An optional widget positioned at the bottom-right corner of the avatar (e.g. status indicator).
  final Widget? badge;

  /// A custom fallback widget rendered when [image] is null and [name] is not provided or empty.
  final Widget? fallback;

  /// Creates a [BloomAvatar].
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

/// An overlapping horizontal stack of user avatars.
///
/// Automatically applies negative margin and borders between children
/// to create a compact avatar cluster.
///
/// ```dart
/// BloomAvatarGroup(
///   overlap: 8,
///   children: const [
///     BloomAvatar(name: 'Alice Cooper'),
///     BloomAvatar(name: 'Bob Ross'),
///     BloomAvatar(name: 'Charlie Chaplin'),
///   ],
/// );
/// ```
class BloomAvatarGroup extends StatelessWidget {
  /// The list of avatar widgets to display within the group.
  final List<Widget> children;

  /// The amount of horizontal overlap in pixels between consecutive avatars. Defaults to 10.
  final double overlap;

  /// Creates a [BloomAvatarGroup].
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
