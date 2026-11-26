import '../events.dart';
import '../framework.dart';
import 'button.dart';
import 'cn.dart';
import 'icons.dart';

/// Standardized error state container with optional retry action.
BloomNode errorState({
  String title = 'Something went wrong',
  String? message,
  String retryLabel = 'Try again',
  BloomEventHandler? onRetry,
  String extraClassName = '',
}) {
  return Div(
    attrs: const {'role': 'alert'},
    className: cn([
      'flex flex-col items-center justify-center text-center p-8 rounded-[var(--radius-lg)] '
          'border border-[var(--destructive)]/30 bg-[var(--destructive)]/5 gap-3',
      extraClassName,
    ]),
    children: [
      Div(
        className:
            'flex h-10 w-10 items-center justify-center rounded-full bg-[var(--destructive)]/15 text-[var(--destructive)]',
        children: [uiIcon('alert-circle', className: 'w-5 h-5')],
      ),
      Div(
        className: 'space-y-1',
        children: [
          H3(
            className: 'text-base font-semibold text-[var(--text)]',
            text: title,
          ),
          if (message != null)
            P(
              className: 'text-sm text-[var(--text-muted)] max-w-md',
              text: message,
            ),
        ],
      ),
      if (onRetry != null)
        button(
          text: retryLabel,
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onClick: onRetry,
        ),
    ],
  );
}
