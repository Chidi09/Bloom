import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

class KarmaRing extends StatelessWidget {
  final int score;
  final double size;

  const KarmaRing({
    super.key,
    required this.score,
    this.size = 80,
  });

  double get _progress => (score % 2500) / 2500;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: _progress,
            strokeWidth: 4,
            backgroundColor: TodoColors.borderDark,
            valueColor: const AlwaysStoppedAnimation<Color>(TodoColors.accent),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TodoTypography.bodySemiBold.copyWith(
                  color: TodoColors.accent,
                ),
              ),
              Text(
                'karma',
                style: TodoTypography.caption.copyWith(
                  fontSize: 9,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
