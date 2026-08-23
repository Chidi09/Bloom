import '../framework.dart';
import 'cn.dart';

/// Form label primitive for Bloom UI.
BloomNode label({
  String? text,
  String? htmlFor,
  bool required = false,
  String extraClassName = '',
  List<BloomNode>? children,
  Map<String, String> attrs = const {},
}) {
  return El(
    'label',
    attrs: {
      if (htmlFor != null) 'for': htmlFor,
      ...attrs,
    },
    className: cn([
      'text-xs font-medium text-[var(--text)] leading-none select-none '
      'peer-disabled:cursor-not-allowed peer-disabled:opacity-70',
      extraClassName,
    ]),
    children: [
      if (text != null) Text(text),
      if (required)
        Span(
          className: 'text-[var(--destructive)] ml-0.5',
          text: '*',
        ),
      if (children != null) ...children,
    ],
  );
}
