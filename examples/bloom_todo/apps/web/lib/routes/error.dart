import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';

/// Standard Bloom Web Error Boundary (`error.dart`).
/// Displayed when an unhandled route or rendering error occurs in the Web application.
class WebErrorView extends StatelessWidget {
  final String? errorMessage;
  final String? location;
  final VoidCallback? onRetry;

  const WebErrorView({
    super.key,
    this.errorMessage,
    this.location,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: BloomCard(
              backgroundColor: const Color(0xFF14141A),
              borderColor: const Color(0xFF27272A),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Icon(Icons.error_outline_rounded, size: 28, color: Color(0xFFEF4444)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Application Error',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage ?? 'An unexpected runtime error occurred.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1AA)),
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF09090B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF22222A)),
                        ),
                        child: Text(
                          location!,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF71717A)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: BloomButton(
                            variant: BloomButtonVariant.outline,
                            size: BloomButtonSize.md,
                            onPressed: onRetry ?? () {},
                            child: const Text('Reload View'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
