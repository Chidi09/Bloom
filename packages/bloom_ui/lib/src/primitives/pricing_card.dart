// lib/src/primitives/pricing_card.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';
import 'badge.dart';
import 'button.dart';
import 'card.dart';

class BloomPricingCard extends StatelessWidget {
  final String planName;
  final String price;
  final String interval;
  final String description;
  final List<String> features;
  final String ctaText;
  final VoidCallback onCtaPressed;
  final bool isPopular;

  const BloomPricingCard({
    super.key,
    required this.planName,
    required this.price,
    this.interval = '/month',
    required this.description,
    required this.features,
    required this.ctaText,
    required this.onCtaPressed,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(context.bloomRadius.lg),
        border: Border.all(
          color: isPopular ? colors.primary : colors.border,
          width: isPopular ? 2.0 : 1.0,
        ),
        boxShadow: isPopular ? const [BloomShadows.s3] : const [BloomShadows.s1],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                planName,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: context.bloomTypography.sans,
                ),
              ),
              if (isPopular)
                const BloomBadge(
                  variant: BloomBadgeVariant.defaultVariant,
                  child: Text('POPULAR'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: context.bloomTypography.sans,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                interval,
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 24),
          BloomButton(
            variant: isPopular ? BloomButtonVariant.defaultVariant : BloomButtonVariant.outline,
            onPressed: onCtaPressed,
            child: Text(ctaText),
          ),
          const SizedBox(height: 24),
          Divider(color: colors.border),
          const SizedBox(height: 16),
          Text(
            'FEATURES INCLUDED',
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ...features.map((f) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(Icons.check, size: 16, color: colors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
