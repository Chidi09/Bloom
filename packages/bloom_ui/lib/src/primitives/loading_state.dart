// lib/src/primitives/loading_state.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'spinner.dart';

class BloomLoadingState extends StatelessWidget {
  final String? message;

  const BloomLoadingState({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BloomSpinner(size: 32, strokeWidth: 3),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: TextStyle(
                  color: context.bloomColors.textSecondary,
                  fontSize: 14,
                  fontFamily: context.bloomTypography.sans,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
