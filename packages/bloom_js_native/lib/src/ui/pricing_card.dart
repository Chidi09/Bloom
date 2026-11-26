import '../events.dart';
import '../framework.dart';
import 'badge.dart';
import 'button.dart';
import 'cn.dart';
import 'icons.dart';

/// SaaS pricing tier card with feature checklist and call-to-action button.
BloomNode pricingCard({
  required String tier,
  required String price,
  String period = '/mo',
  String? description,
  required List<String> features,
  required String ctaLabel,
  BloomEventHandler? onSelect,
  bool highlighted = false,
  String? badgeText,
  String extraClassName = '',
}) {
  return Div(
    className: cn([
      'flex flex-col justify-between rounded-[var(--radius-lg)] border p-6 bg-[var(--card)] text-[var(--card-foreground)] shadow-[var(--shadow-card)] space-y-6',
      highlighted
          ? 'border-[var(--primary)] ring-1 ring-[var(--primary)]'
          : 'border-[var(--border)]',
      extraClassName,
    ]),
    children: [
      Div(
        className: 'space-y-4',
        children: [
          Div(
            className: 'flex items-center justify-between gap-2',
            children: [
              H3(className: 'text-lg font-semibold', text: tier),
              if (badgeText != null)
                badge(label: badgeText, variant: BadgeVariant.defaultVariant),
            ],
          ),
          Div(
            className: 'flex items-baseline gap-1',
            children: [
              Span(className: 'text-3xl font-bold', text: price),
              Span(
                className: 'text-sm text-[var(--text-muted)]',
                text: period,
              ),
            ],
          ),
          if (description != null)
            P(
              className: 'text-sm text-[var(--text-muted)]',
              text: description,
            ),
          Ul(
            className: 'space-y-2 text-sm',
            children: [
              for (final feat in features)
                Li(
                  className: 'flex items-center gap-2',
                  children: [
                    uiIcon('check', className: 'w-4 h-4 text-[var(--primary)] shrink-0'),
                    Span(text: feat),
                  ],
                ),
            ],
          ),
        ],
      ),
      button(
        text: ctaLabel,
        variant:
            highlighted ? ButtonVariant.primary : ButtonVariant.outline,
        extraClassName: 'w-full',
        onClick: onSelect,
      ),
    ],
  );
}
