import '../framework.dart';
import 'cn.dart';
import 'toggle.dart';

/// Single item in a [toggleGroupSingle] or [toggleGroupMultiple].
typedef ToggleGroupItem<T> = ({T value, BloomNode child, String? ariaLabel});

/// Controlled toggle group supporting single-selection.
BloomNode toggleGroupSingle<T>({
  required List<ToggleGroupItem<T>> items,
  required T? value,
  required void Function(T value) onChange,
  ToggleVariant variant = ToggleVariant.defaultVariant,
  ToggleSize size = ToggleSize.defaultSize,
  String orientation = 'horizontal',
  String extraClassName = '',
}) {
  final isHorizontal = orientation == 'horizontal';

  return Div(
    attrs: {
      'role': 'group',
      'data-slot': 'toggle-group',
      'aria-orientation': orientation,
    },
    className: cn([
      'inline-flex items-center gap-1 rounded-[var(--radius-md)] p-1 bg-[var(--card)] border border-[var(--border)]',
      isHorizontal ? 'flex-row' : 'flex-col',
      extraClassName,
    ]),
    children: items.map((item) {
      final isSelected = item.value == value;

      return toggle(
        pressed: isSelected,
        onChange: (pressed) {
          if (pressed) onChange(item.value);
        },
        variant: variant,
        size: size,
        child: item.child,
      );
    }).toList(),
  );
}

/// Controlled toggle group supporting multiple selections.
BloomNode toggleGroupMultiple<T>({
  required List<ToggleGroupItem<T>> items,
  required Set<T> value,
  required void Function(Set<T> value) onChange,
  ToggleVariant variant = ToggleVariant.defaultVariant,
  ToggleSize size = ToggleSize.defaultSize,
  String orientation = 'horizontal',
  String extraClassName = '',
}) {
  final isHorizontal = orientation == 'horizontal';

  return Div(
    attrs: {
      'role': 'group',
      'data-slot': 'toggle-group',
      'aria-orientation': orientation,
    },
    className: cn([
      'inline-flex items-center gap-1 rounded-[var(--radius-md)] p-1 bg-[var(--card)] border border-[var(--border)]',
      isHorizontal ? 'flex-row' : 'flex-col',
      extraClassName,
    ]),
    children: items.map((item) {
      final isSelected = value.contains(item.value);

      return toggle(
        pressed: isSelected,
        onChange: (pressed) {
          final next = Set<T>.from(value);
          if (pressed) {
            next.add(item.value);
          } else {
            next.remove(item.value);
          }
          onChange(next);
        },
        variant: variant,
        size: size,
        child: item.child,
      );
    }).toList(),
  );
}
