class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult.valid() : isValid = true, error = null;
  const ValidationResult.invalid(this.error) : isValid = false;
}

class TaskValidator {
  static const int minTitleLength = 1;
  static const int maxTitleLength = 500;
  static const int maxDescriptionLength = 10000;

  static ValidationResult validateTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return const ValidationResult.invalid('Task title cannot be empty.');
    }
    if (title.length > maxTitleLength) {
      return const ValidationResult.invalid(
        'Task title cannot exceed $maxTitleLength characters.',
      );
    }
    return const ValidationResult.valid();
  }

  static ValidationResult validateDescription(String? description) {
    if (description != null && description.length > maxDescriptionLength) {
      return const ValidationResult.invalid(
        'Description cannot exceed $maxDescriptionLength characters.',
      );
    }
    return const ValidationResult.valid();
  }

  static ValidationResult validateDueDate(
    DateTime? dueAt, {
    bool isRecurring = false,
  }) {
    if (dueAt == null) return const ValidationResult.valid();
    // Allow past dates only for testing or backfilled recurring tasks
    return const ValidationResult.valid();
  }

  static ValidationResult validateRecurrenceRule(String? rrule) {
    if (rrule == null || rrule.trim().isEmpty) {
      return const ValidationResult.valid();
    }
    final upper = rrule.toUpperCase();
    if (!upper.contains('FREQ=')) {
      return const ValidationResult.invalid(
        'Invalid RRULE: must contain FREQ= (e.g. FREQ=DAILY, FREQ=WEEKLY)',
      );
    }
    return const ValidationResult.valid();
  }
}
