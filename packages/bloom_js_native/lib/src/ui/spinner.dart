import '../framework.dart';
import 'cn.dart';
import 'icons.dart';

/// Size presets for [spinner].
enum SpinnerSize {
  /// Compact 16px spinner.
  sm,

  /// Standard 24px spinner.
  md,

  /// Large 36px spinner.
  lg,
}

/// Accessible animated loading spinner.
BloomNode spinner({
  SpinnerSize size = SpinnerSize.md,
  String label = 'Loading',
  String extraClassName = '',
}) {
  final sizeCls = switch (size) {
    SpinnerSize.sm => 'w-4 h-4',
    SpinnerSize.md => 'w-6 h-6',
    SpinnerSize.lg => 'w-9 h-9',
  };
  return Span(
    attrs: {
      'role': 'status',
      'aria-label': label,
    },
    className: cn(['inline-flex items-center justify-center', extraClassName]),
    children: [
      uiIcon(
        'spinner',
        className: cn([sizeCls, 'animate-spin text-[var(--primary)]']),
      ),
    ],
  );
}
