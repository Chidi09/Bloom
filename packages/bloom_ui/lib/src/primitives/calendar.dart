// lib/src/primitives/calendar.dart
import 'package:flutter/widgets.dart';
import '../icons/bloom_icon.dart';
import '../icons/bloom_icon_data.dart';
import '../icons/bloom_icons.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/extensions.dart';

/// Selection mode for [BloomCalendar].
enum BloomCalendarMode {
  /// Allows selecting a single day.
  single,

  /// Allows selecting a contiguous start-to-end date range.
  range,
}

/// An inline calendar primitive for month navigation and single or range date selection.
///
/// Styled matching shadcn base-nova with 7-column weekday grids, month pagination controls,
/// and highlighted selection/today states.
///
/// ```dart
/// // Single date selection
/// BloomCalendar.single(
///   selected: selectedDate,
///   onDaySelected: (day) => setState(() => selectedDate = day),
/// )
///
/// // Date range selection
/// BloomCalendar.range(
///   rangeStart: rangeStart,
///   rangeEnd: rangeEnd,
///   onRangeSelected: (range) => setState(() {
///     rangeStart = range.$1;
///     rangeEnd = range.$2;
///   }),
/// )
/// ```
class BloomCalendar extends StatefulWidget {
  /// The active selection mode of the calendar.
  final BloomCalendarMode mode;

  /// The currently selected date in [BloomCalendarMode.single] mode.
  final DateTime? selected;

  /// The start date of the selected range in [BloomCalendarMode.range] mode.
  final DateTime? rangeStart;

  /// The end date of the selected range in [BloomCalendarMode.range] mode.
  final DateTime? rangeEnd;

  /// The initial month displayed when the calendar first renders.
  ///
  /// Defaults to the current month if omitted.
  final DateTime? initialMonth;

  /// Callback invoked when a day is tapped in [BloomCalendarMode.single] mode.
  final ValueChanged<DateTime>? onDaySelected;

  /// Callback invoked when a range is selected or updated in [BloomCalendarMode.range] mode.
  final ValueChanged<(DateTime?, DateTime?)>? onRangeSelected;

  /// Callback invoked when the user navigates between months.
  final ValueChanged<DateTime>? onMonthChanged;

  /// Creates a [BloomCalendar] in single date selection mode.
  const BloomCalendar.single({
    super.key,
    this.selected,
    this.initialMonth,
    this.onDaySelected,
    this.onRangeSelected,
    this.onMonthChanged,
  })  : mode = BloomCalendarMode.single,
        rangeStart = null,
        rangeEnd = null;

  /// Creates a [BloomCalendar] in date range selection mode.
  const BloomCalendar.range({
    super.key,
    this.rangeStart,
    this.rangeEnd,
    this.initialMonth,
    this.onRangeSelected,
    this.onMonthChanged,
  })  : mode = BloomCalendarMode.range,
        selected = null,
        onDaySelected = null;

  @override
  State<BloomCalendar> createState() => _BloomCalendarState();
}

class _BloomCalendarState extends State<BloomCalendar> {
  static const List<String> _weekdayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  DateTime? _displayMonth;
  DateTime _rangeStart = DateTime(0);
  DateTime? _rangeEnd;

  DateTime get _display {
    return _displayMonth ??=
        DateTime(widget.initialMonth?.year ?? DateTime.now().year,
            widget.initialMonth?.month ?? DateTime.now().month);
  }

  void _setMonth(int year, int month) {
    final next = DateTime(year, month);
    setState(() => _displayMonth = next);
    widget.onMonthChanged?.call(next);
  }

  void _prevMonth() {
    final m = _display;
    _setMonth(m.month == 1 ? m.year - 1 : m.year, m.month == 1 ? 12 : m.month - 1);
  }

  void _nextMonth() {
    final m = _display;
    _setMonth(m.month == 12 ? m.year + 1 : m.year, m.month == 12 ? 1 : m.month + 1);
  }

  void _handleSelect(DateTime day) {
    switch (widget.mode) {
      case BloomCalendarMode.single:
        widget.onDaySelected?.call(day);
      case BloomCalendarMode.range:
        if (_rangeEnd != null && _rangeStart.year != 0 && _sameDay(_rangeStart, _rangeEnd!)) {
          _rangeStart = day;
          _rangeEnd = null;
        } else if (_rangeStart.year == 0 || _rangeEnd != null) {
          _rangeStart = day;
          _rangeEnd = null;
        } else if (day.isBefore(_rangeStart)) {
          _rangeStart = day;
        } else {
          _rangeEnd = day;
        }
        setState(() {});
        widget.onRangeSelected?.call((_rangeStart, _rangeEnd));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;
    final spacing = theme.spacing;

    final months = _monthGrid(_display, weekStartMonday: true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        SizedBox(height: spacing.s2),
        Row(
          children: _weekdayLabels
              .map((l) => Expanded(
                    child: Center(
                      child: Text(
                        l,
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: theme.typography.sans,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        SizedBox(height: spacing.s2),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: _weeks(months).map((week) {
            return Row(
              children: week.map((d) => Expanded(child: _buildDayCell(context, d))).toList(),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<List<DateTime>> _weeks(List<DateTime> days) {
    final weeks = <List<DateTime>>[];
    for (var i = 0; i < days.length; i += 7) {
      final end = i + 7 < days.length ? i + 7 : days.length;
      weeks.add(days.sublist(i, end));
    }
    return weeks;
  }

  Widget _buildHeader(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;
    final monthLabel = '${_monthName(_display.month)} ${_display.year}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _MonthNavButton(icon: BloomIcons.chevronLeft, onTap: _prevMonth),
        Text(
          monthLabel,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: theme.typography.sans,
          ),
        ),
        _MonthNavButton(icon: BloomIcons.chevronRight, onTap: _nextMonth),
      ],
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime day) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;
    final inCurrentMonth = day.month == _display.month && day.year == _display.year;

    final today = DateTime.now();
    final isToday =
        day.day == today.day && day.month == today.month && day.year == today.year;

    final isSelected = _isSelected(day);
    final isRangeStart = _isRangeStart(day);
    final isRangeEnd = _isRangeEnd(day);

    Color bg = BloomColors.transparent;
    Color fg = inCurrentMonth ? colors.textPrimary : colors.textTertiary.withValues(alpha: 0.4);

    if (isSelected || isRangeStart || isRangeEnd) {
      bg = colors.primary;
      fg = colors.primaryForeground;
    }

    return Semantics(
      button: true,
      selected: isSelected || isRangeStart || isRangeEnd,
      onTap: inCurrentMonth ? () => _handleSelect(day) : null,
      label: day.toLocal().toIso8601String().substring(0, 10),
      child: BloomPressable(
        onTap: inCurrentMonth ? () => _handleSelect(day) : null,
        borderRadius: BorderRadius.circular(theme.radius.md),
        enabled: inCurrentMonth,
        child: AnimatedContainer(
          duration: BloomMotion.instant,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: isToday ? Border.all(color: colors.primary, width: 1.5) : null,
            borderRadius: BorderRadius.circular(theme.radius.md),
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: isToday || isSelected ? FontWeight.w600 : FontWeight.w400,
              fontFamily: theme.typography.sans,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSelected(DateTime day) {
    if (widget.mode == BloomCalendarMode.single) {
      final s = widget.selected;
      return s != null && s.day == day.day && s.month == day.month && s.year == day.year;
    }
    return _isRangeStart(day) || _isRangeEnd(day);
  }

  bool _isRangeStart(DateTime day) {
    return _rangeStart.year != 0 && _sameDay(_rangeStart, day);
  }

  bool _isRangeEnd(DateTime day) {
    return _rangeEnd != null && _sameDay(_rangeEnd!, day);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }

  static List<DateTime> _monthGrid(DateTime month, {required bool weekStartMonday}) {
    final first = DateTime(month.year, month.month, 1);
    final firstWeekday = first.weekday; // 1=Monday .. 7=Sunday
    final leading = (firstWeekday - 1) % 7;
    final cells = <DateTime>[];
    final firstCell = first.subtract(Duration(days: leading));
    for (int i = 0; i < 42; i++) {
      cells.add(DateTime(firstCell.year, firstCell.month, firstCell.day + i));
    }
    return cells;
  }
}

class _MonthNavButton extends StatelessWidget {
  final BloomIconData icon;
  final VoidCallback onTap;

  const _MonthNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.bloomTheme;
    return Semantics(
      button: true,
      child: BloomPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radius.md),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.radius.md),
            border: Border.all(color: theme.colors.border),
          ),
          child: BloomIcon(icon, size: 18, color: theme.colors.textSecondary),
        ),
      ),
    );
  }
}
