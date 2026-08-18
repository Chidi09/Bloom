enum Frequency { daily, weekly, monthly, yearly }

class RecurrenceRule {
  final Frequency frequency;
  final int interval;
  final List<String> byDay; // ['MO', 'WE', 'FR']
  final DateTime? until;

  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.byDay = const [],
    this.until,
  });

  @override
  String toString() {
    final buffer = StringBuffer('Every ');
    if (interval > 1) {
      buffer.write('$interval ');
      buffer.write(switch (frequency) {
        Frequency.daily => 'days',
        Frequency.weekly => 'weeks',
        Frequency.monthly => 'months',
        Frequency.yearly => 'years',
      });
    } else {
      buffer.write(switch (frequency) {
        Frequency.daily => 'day',
        Frequency.weekly => 'week',
        Frequency.monthly => 'month',
        Frequency.yearly => 'year',
      });
    }

    if (byDay.isNotEmpty) {
      buffer.write(' on ${byDay.join(', ')}');
    }

    if (until != null) {
      buffer.write(' until ${until!.toIso8601String().split('T').first}');
    }

    return buffer.toString();
  }
}

class RecurrenceParser {
  static RecurrenceRule parse(String rrule) {
    Frequency freq = Frequency.daily;
    int interval = 1;
    List<String> byDay = [];
    DateTime? until;

    final parts = rrule.split(';');
    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      final key = kv[0].toUpperCase().trim();
      final value = kv[1].toUpperCase().trim();

      switch (key) {
        case 'FREQ':
          freq = switch (value) {
            'DAILY' => Frequency.daily,
            'WEEKLY' => Frequency.weekly,
            'MONTHLY' => Frequency.monthly,
            'YEARLY' => Frequency.yearly,
            _ => Frequency.daily,
          };
        case 'INTERVAL':
          interval = int.tryParse(value) ?? 1;
        case 'BYDAY':
          byDay = value.split(',').map((d) => d.trim()).toList();
        case 'UNTIL':
          until = DateTime.tryParse(value);
      }
    }

    return RecurrenceRule(
      frequency: freq,
      interval: interval,
      byDay: byDay,
      until: until,
    );
  }

  static DateTime nextOccurrence(RecurrenceRule rule, DateTime after) {
    return switch (rule.frequency) {
      Frequency.daily => after.add(Duration(days: rule.interval)),
      Frequency.weekly => after.add(Duration(days: 7 * rule.interval)),
      Frequency.monthly => DateTime(
        after.year,
        after.month + rule.interval,
        after.day,
        after.hour,
        after.minute,
      ),
      Frequency.yearly => DateTime(
        after.year + rule.interval,
        after.month,
        after.day,
        after.hour,
        after.minute,
      ),
    };
  }
}
