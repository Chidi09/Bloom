import 'package:test/test.dart';
import 'package:bloom_todo_core/core.dart';

void main() {
  group('Task Validator', () {
    test('validates non-empty title', () {
      final valid = TaskValidator.validateTitle('Buy groceries');
      expect(valid.isValid, isTrue);

      final empty = TaskValidator.validateTitle('   ');
      expect(empty.isValid, isFalse);
      expect(empty.error, contains('cannot be empty'));
    });

    test('validates RRULE syntax', () {
      final valid = TaskValidator.validateRecurrenceRule('FREQ=DAILY;INTERVAL=1');
      expect(valid.isValid, isTrue);

      final invalid = TaskValidator.validateRecurrenceRule('INVALID_RULE');
      expect(invalid.isValid, isFalse);
    });
  });

  group('Recurrence Parser', () {
    test('parses daily frequency and computes next occurrence', () {
      final rule = RecurrenceParser.parse('FREQ=DAILY;INTERVAL=2');
      expect(rule.frequency, equals(Frequency.daily));
      expect(rule.interval, equals(2));

      final start = DateTime(2026, 8, 18, 10, 0);
      final next = RecurrenceParser.nextOccurrence(rule, start);
      expect(next, equals(DateTime(2026, 8, 20, 10, 0)));
    });

    test('human readable recurrence string', () {
      final rule = RecurrenceParser.parse('FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE,FR');
      expect(rule.toString(), equals('Every week on MO, WE, FR'));
    });
  });

  group('Task Model', () {
    test('serializes to and from JSON', () {
      final now = DateTime.now().toUtc();
      final task = Task(
        id: 'tsk_123',
        projectId: 'prj_456',
        workspaceId: 'ws_789',
        creatorId: 'usr_001',
        title: 'Ship Bloom Todo',
        priority: Priority.p1,
        createdAt: now,
        updatedAt: now,
      );

      final json = task.toJson();
      final restored = Task.fromJson(json);

      expect(restored.id, equals(task.id));
      expect(restored.title, equals(task.title));
      expect(restored.priority, equals(Priority.p1));
    });
  });
}
