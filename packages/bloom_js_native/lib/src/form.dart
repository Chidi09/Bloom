// lib/src/form.dart
import 'package:signals/signals.dart';

// ─── Validators ───────────────────────────────────────────────────────────────

/// Fails for empty or whitespace-only strings.
String? Function(String) required([String? message]) =>
    (v) => v.trim().isEmpty ? (message ?? 'This field is required.') : null;

/// Fails when the value is shorter than [n] characters.
String? Function(String) minLength(int n, [String? message]) =>
    (v) => v.length < n ? (message ?? 'Must be at least $n characters.') : null;

/// Fails when the value is longer than [n] characters.
String? Function(String) maxLength(int n, [String? message]) =>
    (v) => v.length > n ? (message ?? 'Must be at most $n characters.') : null;

/// Fails when the value is not a valid email address.
String? Function(String) email([String? message]) {
  final re = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
  return (v) =>
      re.hasMatch(v) ? null : (message ?? 'Enter a valid email address.');
}

/// Fails when the value does not match [re].
String? Function(String) pattern(RegExp re, [String? message]) =>
    (v) => re.hasMatch(v) ? null : (message ?? 'Invalid format.');

// ─── BloomFormField ───────────────────────────────────────────────────────────

/// A single reactive form field.
class BloomFormField {
  final String _initialValue;
  final List<String? Function(String)> validators;

  late final Signal<String> value;
  late final Signal<List<String>> errors;
  late final Signal<bool> isDirty;
  late final Signal<bool> isTouched;
  late final ReadonlySignal<bool> isValid;

  BloomFormField({
    String initialValue = '',
    this.validators = const [],
  }) : _initialValue = initialValue {
    value = signal(initialValue);
    errors = signal<List<String>>([]);
    isDirty = signal(false);
    isTouched = signal(false);
    isValid = computed(() => errors.value.isEmpty);
  }

  /// Updates the value and marks the field dirty.
  void setValue(String newValue) {
    value.value = newValue;
    isDirty.value = true;
  }

  /// Marks the field as touched (e.g. on blur).
  void touch() => isTouched.value = true;

  /// Runs all validators and updates [errors]. Returns `true` if valid.
  bool validate() {
    final errs = <String>[];
    for (final v in validators) {
      final err = v(value.value);
      if (err != null) errs.add(err);
    }
    errors.value = errs;
    return errs.isEmpty;
  }

  /// Resets to initial value and clears all state.
  void reset() {
    value.value = _initialValue;
    errors.value = [];
    isDirty.value = false;
    isTouched.value = false;
  }
}

// ─── BloomForm ────────────────────────────────────────────────────────────────

/// Reactive controller for a collection of [BloomFormField]s.
class BloomForm {
  final Map<String, BloomFormField> _fields;

  late final ReadonlySignal<bool> isValid;
  late final ReadonlySignal<bool> isDirty;
  final Signal<bool> isSubmitting = signal(false);

  BloomForm(Map<String, BloomFormField> fields) : _fields = fields {
    isValid = computed(() => _fields.values.every((f) => f.isValid.value));
    isDirty = computed(() => _fields.values.any((f) => f.isDirty.value));
  }

  /// Returns the [BloomFormField] registered under [name]. Throws [StateError] if absent.
  BloomFormField getField(String name) {
    final field = _fields[name];
    if (field == null) {
      throw StateError(
          'BloomForm: No field registered with name "$name".');
    }
    return field;
  }

  /// Returns the current string value of the field named [name].
  String getValue(String name) => getField(name).value.value;

  /// Snapshot map of all current field values.
  Map<String, String> get values =>
      {for (final entry in _fields.entries) entry.key: entry.value.value.value};

  /// Validates all fields. Returns `true` if every field passes.
  bool validate() =>
      _fields.values.map((f) => f.validate()).every((r) => r);

  /// If valid, calls [onSubmit] with current values and wraps it with [isSubmitting].
  Future<void> submit(
      Future<void> Function(Map<String, String> values) onSubmit) async {
    if (!validate()) return;
    isSubmitting.value = true;
    try {
      await onSubmit(values);
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Resets all fields to their initial state.
  void reset() {
    for (final field in _fields.values) {
      field.reset();
    }
    isSubmitting.value = false;
  }
}
