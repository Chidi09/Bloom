import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bloom_todo_ui/ui.dart';

/// Standard Bloom File-Based Error Boundary (`error.dart`).
/// Rendered when route resolution fails or an unhandled exception occurs in the navigation tree.
class ErrorPage extends StatelessWidget {
  final GoRouterState state;

  const ErrorPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final errorMessage = state.error?.message ?? 'The requested screen could not be loaded.';
    final location = state.uri.toString();

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BloomCard(
                backgroundColor: const Color(0xFF14141A),
                borderColor: const Color(0xFF27272A),
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                        'Page Not Found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1AA)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF09090B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF22222A)),
                        ),
                        child: Text(
                          location,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF71717A)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: BloomButton(
                              variant: BloomButtonVariant.outline,
                              size: BloomButtonSize.md,
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/today');
                                }
                              },
                              child: const Text('Go Back'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: BloomButton(
                              variant: BloomButtonVariant.defaultVariant,
                              size: BloomButtonSize.md,
                              onPressed: () => context.go('/today'),
                              child: const Text('Home Focus'),
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
      ),
    );
  }
}
