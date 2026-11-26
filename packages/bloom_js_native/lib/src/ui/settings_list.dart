import '../framework.dart';
import 'cn.dart';

/// Grouped settings section with title, optional description, and list of [settingsTile] rows.
BloomNode settingsSection({
  required String title,
  String? description,
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return Section(
    className: cn(['space-y-3', extraClassName]),
    children: [
      Div(
        className: 'space-y-0.5',
        children: [
          H3(
            className: 'text-base font-semibold text-[var(--text)]',
            text: title,
          ),
          if (description != null)
            P(
              className: 'text-xs text-[var(--text-muted)]',
              text: description,
            ),
        ],
      ),
      Div(
        className:
            'divide-y divide-[var(--border)] rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--card)]',
        children: children,
      ),
    ],
  );
}

/// Individual setting row pairing label/description with a trailing [control].
BloomNode settingsTile({
  required String title,
  String? description,
  required BloomNode control,
  String extraClassName = '',
}) {
  return Div(
    className: cn([
      'flex items-center justify-between gap-4 px-4 py-3',
      extraClassName,
    ]),
    children: [
      Div(
        className: 'space-y-0.5 min-w-0',
        children: [
          Div(
            className: 'text-sm font-medium text-[var(--text)]',
            text: title,
          ),
          if (description != null)
            Div(
              className: 'text-xs text-[var(--text-muted)]',
              text: description,
            ),
        ],
      ),
      Div(className: 'shrink-0', children: [control]),
    ],
  );
}
