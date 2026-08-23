import '../framework.dart';
import 'cn.dart';
import 'icons.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

/// Controlled month-grid date picker component.
///
/// Caller owns both the displayed month and the selected date.
BloomNode calendar({
  required DateTime month,
  DateTime? selected,
  required void Function(DateTime date) onSelect,
  required void Function(DateTime month) onMonthChange,
  String extraClassName = '',
}) {
  final currentYear = month.year;
  final currentMonth = month.month;
  final monthTitle = '${_monthNames[currentMonth - 1]} $currentYear';

  final firstDay = DateTime(currentYear, currentMonth, 1);
  final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
  final startWeekday = firstDay.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat

  final prevMonthDays = DateTime(currentYear, currentMonth, 0).day;
  final totalCells = ((startWeekday + daysInMonth + 6) ~/ 7) * 7;

  final now = DateTime.now();

  return Div(
    attrs: const {'data-slot': 'calendar'},
    className: cn([
      'p-3 w-fit bg-[var(--card)] border border-[var(--border)] rounded-[var(--radius-lg)] shadow-[var(--shadow-card)] flex flex-col gap-3 select-none',
      extraClassName,
    ]),
    children: [
      // Navigation Header
      Div(
        className: 'flex items-center justify-between px-1',
        children: [
          El(
            'button',
            attrs: const {
              'type': 'button',
              'aria-label': 'Previous month',
            },
            className:
                'h-7 w-7 flex items-center justify-center rounded-[var(--radius-sm)] '
                'text-[var(--text-muted)] hover:text-[var(--text)] hover:bg-[var(--bg-muted)] '
                'transition-colors cursor-pointer',
            onClick: (_) => onMonthChange(DateTime(currentYear, currentMonth - 1, 1)),
            children: [uiIcon('chevron-left', className: 'w-4 h-4')],
          ),
          Span(
            className: 'text-xs sm:text-sm font-semibold text-[var(--text)]',
            text: monthTitle,
          ),
          El(
            'button',
            attrs: const {
              'type': 'button',
              'aria-label': 'Next month',
            },
            className:
                'h-7 w-7 flex items-center justify-center rounded-[var(--radius-sm)] '
                'text-[var(--text-muted)] hover:text-[var(--text)] hover:bg-[var(--bg-muted)] '
                'transition-colors cursor-pointer',
            onClick: (_) => onMonthChange(DateTime(currentYear, currentMonth + 1, 1)),
            children: [uiIcon('chevron-right', className: 'w-4 h-4')],
          ),
        ],
      ),
      // Weekday headers
      Div(
        className: 'grid grid-cols-7 gap-1 text-center',
        children: _weekdays
            .map((wd) => Div(
                  className:
                      'h-7 flex items-center justify-center text-[10px] sm:text-xs font-medium text-[var(--text-muted)]',
                  text: wd,
                ))
            .toList(),
      ),
      // Day cells
      Div(
        className: 'grid grid-cols-7 gap-1',
        children: List.generate(totalCells, (index) {
          late final DateTime cellDate;
          late final bool isOutside;

          if (index < startWeekday) {
            // Previous month day
            final day = prevMonthDays - startWeekday + index + 1;
            cellDate = DateTime(currentYear, currentMonth - 1, day);
            isOutside = true;
          } else if (index >= startWeekday + daysInMonth) {
            // Next month day
            final day = index - (startWeekday + daysInMonth) + 1;
            cellDate = DateTime(currentYear, currentMonth + 1, day);
            isOutside = true;
          } else {
            // Current month day
            final day = index - startWeekday + 1;
            cellDate = DateTime(currentYear, currentMonth, day);
            isOutside = false;
          }

          final isSelected = selected != null &&
              selected.year == cellDate.year &&
              selected.month == cellDate.month &&
              selected.day == cellDate.day;

          final isToday = now.year == cellDate.year &&
              now.month == cellDate.month &&
              now.day == cellDate.day;

          return El(
            'button',
            attrs: {
              'type': 'button',
              'data-slot': 'calendar-day',
              'data-selected': isSelected ? 'true' : 'false',
              'data-outside': isOutside ? 'true' : 'false',
              'aria-label': '${cellDate.year}-${cellDate.month}-${cellDate.day}',
            },
            className: cn([
              'h-7 w-7 sm:h-8 sm:w-8 flex items-center justify-center rounded-[var(--radius-sm)] text-xs font-normal transition-colors cursor-pointer',
              isSelected
                  ? 'bg-[var(--primary)] text-[var(--primary-foreground)] font-medium hover:bg-[var(--primary-hover)] shadow-sm'
                  : isOutside
                      ? 'text-[var(--text-faint)] opacity-40 hover:bg-[var(--bg-muted)] hover:text-[var(--text-muted)]'
                      : isToday
                          ? 'bg-[var(--bg-muted)] text-[var(--text)] font-semibold border border-[var(--border)]'
                          : 'text-[var(--text)] hover:bg-[var(--bg-muted)]',
            ]),
            onClick: (_) => onSelect(cellDate),
            text: '${cellDate.day}',
          );
        }),
      ),
    ],
  );
}
