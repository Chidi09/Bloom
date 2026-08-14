// lib/src/primitives/avatar.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallback;
  final double size;
  final ShapeBorder shape;

  const BloomAvatar({
    super.key,
    this.imageUrl,
    required this.fallback,
    this.size = 40.0,
    this.shape = const CircleBorder(),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        shape: shape,
        color: colors.primary.withOpacity(0.12),
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl == null
          ? Text(
              fallback.isNotEmpty ? fallback.substring(0, 1).toUpperCase() : '',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4,
                fontFamily: context.bloomTypography.sans,
              ),
            )
          : null,
    );
  }
}
