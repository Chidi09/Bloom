import '../framework.dart';
import 'cn.dart';

/// Form field layout wrapper with label, control, and optional help or error text.
BloomNode formField({
  required String label,
  required BloomNode control,
  String? id,
  String? error,
  String? help,
  bool required = false,
  String extraClassName = '',
}) {
  return Div(
    className: cn(['flex flex-col gap-1.5', extraClassName]),
    children: [
      El(
        'label',
        attrs: id != null ? {'for': id} : const {},
        className:
            'text-xs font-medium text-[var(--text)] leading-none select-none',
        children: [
          Text(label),
          if (required)
            Span(
              className: 'text-[var(--destructive)] ml-0.5',
              text: '*',
            ),
        ],
      ),
      control,
      if (error != null && error.isNotEmpty)
        P(
          attrs: id != null ? {'id': '$id-help', 'role': 'alert'} : const {'role': 'alert'},
          className: 'text-xs text-[var(--destructive)] leading-normal',
          text: error,
        )
      else if (help != null && help.isNotEmpty)
        P(
          attrs: id != null ? {'id': '$id-help'} : const {},
          className: 'text-xs text-[var(--text-muted)] leading-normal',
          text: help,
        ),
    ],
  );
}

/// Fieldset container grouping related form fields.
BloomNode fieldSet({
  required List<BloomNode> children,
  String? legend,
  String extraClassName = '',
}) {
  return El(
    'fieldset',
    className: cn(['flex flex-col gap-4', extraClassName]),
    children: [
      if (legend != null)
        El(
          'legend',
          className: 'text-sm font-semibold text-[var(--text)] mb-2',
          text: legend,
        ),
      ...children,
    ],
  );
}

/// Field group container for stacking or arranging multiple fields.
BloomNode fieldGroup({
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return Div(
    className: cn(['flex flex-col gap-4', extraClassName]),
    children: children,
  );
}
