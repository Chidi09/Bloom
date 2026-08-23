// lib/src/form.dart
//
// Pure-Dart reactive form management system for Bloom JS Native.
// Safe for both SSR (VM) and browser DOM mounting.

import 'package:signals/signals.dart';

// ─── Validators ───────────────────────────────────────────────────────────────

/// Creates a validator that fails when a string value is empty or consists solely of whitespace.
///
/// Returns [message] (or `'This field is required.'` by default) when invalid,
/// and `null` when valid.
///
/// ```dart
/// final nameField = BloomFormField(
///   validators: [required('Full name is required.')],
/// );
/// ```
String? Function(String) required([String? message]) =>
    (v) => v.trim().isEmpty ? (message ?? 'This field is required.') : null;

/// Creates a validator that fails when a string value has fewer than [n] characters.
///
/// Returns [message] (or `'Must be at least $n characters.'` by default) when invalid,
/// and `null` when valid.
///
/// ```dart
/// final passwordField = BloomFormField(
///   validators: [minLength(8, 'Password must be at least 8 characters.')],
/// );
/// ```
String? Function(String) minLength(int n, [String? message]) =>
    (v) => v.length < n ? (message ?? 'Must be at least $n characters.') : null;

/// Creates a validator that fails when a string value exceeds [n] characters.
///
/// Returns [message] (or `'Must be at most $n characters.'` by default) when invalid,
/// and `null` when valid.
///
/// ```dart
/// final bioField = BloomFormField(
///   validators: [maxLength(280, 'Bio cannot exceed 280 characters.')],
/// );
/// ```
String? Function(String) maxLength(int n, [String? message]) =>
    (v) => v.length > n ? (message ?? 'Must be at most $n characters.') : null;

/// Creates a validator that fails when a string value is not a valid email address.
///
/// Evaluates input against standard RFC 5322 compatible email regular expression.
/// Returns [message] (or `'Enter a valid email address.'` by default) when invalid,
/// and `null` when valid.
///
/// ```dart
/// final emailField = BloomFormField(
///   validators: [required(), email()],
/// );
/// ```
String? Function(String) email([String? message]) {
  final re = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
  return (v) =>
      re.hasMatch(v) ? null : (message ?? 'Enter a valid email address.');
}

/// Creates a validator that fails when a string value does not match regular expression [re].
///
/// Returns [message] (or `'Invalid format.'` by default) when invalid, and `null` when valid.
///
/// ```dart
/// final zipField = BloomFormField(
///   validators: [pattern(RegExp(r'^\d{5}$'), 'Zip code must be 5 digits.')],
/// );
/// ```
String? Function(String) pattern(RegExp re, [String? message]) =>
    (v) => re.hasMatch(v) ? null : (message ?? 'Invalid format.');

/// Creates a generic validator that fails when a value is `null`, an empty string, or an empty collection.
///
/// Works across arbitrary typed fields ([BloomTypedFormField]), file fields ([BloomFileField]),
/// and collections ([BloomFieldArray]). Returns [message] (or `'This field is required.'` by default).
///
/// ```dart
/// final categoryField = BloomTypedFormField<String?>(
///   initialValue: null,
///   validators: [requiredValue('Please select a category.')],
/// );
/// ```
String? Function(T?) requiredValue<T>([String? message]) => (v) {
      if (v == null) return message ?? 'This field is required.';
      if (v is String && v.trim().isEmpty) {
        return message ?? 'This field is required.';
      }
      if (v is Iterable && v.isEmpty) {
        return message ?? 'This field is required.';
      }
      if (v is Map && v.isEmpty) {
        return message ?? 'This field is required.';
      }
      return null;
    };

/// Alias for [requiredValue] validator.
String? Function(T?) typedRequired<T>([String? message]) =>
    requiredValue<T>(message);

/// Creates a validator for boolean fields that fails when the value is `false`.
///
/// Commonly used for terms of service checkboxes or mandatory confirmations.
/// Returns [message] (or `'Must be accepted.'` by default).
///
/// ```dart
/// final termsField = BloomTypedFormField<bool>(
///   initialValue: false,
///   validators: [requiredTrue('You must accept the terms of service.')],
/// );
/// ```
String? Function(bool) requiredTrue([String? message]) =>
    (v) => v ? null : (message ?? 'Must be accepted.');

/// Creates a validator that fails when a numeric value is less than [minValue].
///
/// Returns [message] (or `'Must be at least $minValue.'` by default) when invalid.
///
/// ```dart
/// final ageField = BloomTypedFormField<int>(
///   initialValue: 18,
///   validators: [min(18, 'Must be at least 18 years old.')],
/// );
/// ```
String? Function(T) min<T extends num>(T minValue, [String? message]) =>
    (v) => v < minValue ? (message ?? 'Must be at least $minValue.') : null;

/// Creates a validator that fails when a numeric value exceeds [maxValue].
///
/// Returns [message] (or `'Must be at most $maxValue.'` by default) when invalid.
///
/// ```dart
/// final scoreField = BloomTypedFormField<double>(
///   initialValue: 100.0,
///   validators: [max(100.0, 'Score cannot exceed 100.0.')],
/// );
/// ```
String? Function(T) max<T extends num>(T maxValue, [String? message]) =>
    (v) => v > maxValue ? (message ?? 'Must be at most $maxValue.') : null;

/// Creates a validator that fails when a numeric value falls outside the inclusive range [[minValue], [maxValue]].
///
/// Returns [message] (or `'Must be between $minValue and $maxValue.'` by default).
///
/// ```dart
/// final ratingField = BloomTypedFormField<int>(
///   initialValue: 3,
///   validators: [range(1, 5, 'Rating must be between 1 and 5.')],
/// );
/// ```
String? Function(T) range<T extends num>(T minValue, T maxValue,
        [String? message]) =>
    (v) => (v < minValue || v > maxValue)
        ? (message ?? 'Must be between $minValue and $maxValue.')
        : null;

/// Creates a validator that fails when an [Iterable] collection has fewer than [n] items.
///
/// Returns [message] (or `'Must have at least $n items.'` by default).
///
/// ```dart
/// final tagsField = BloomTypedFormField<List<String>>(
///   initialValue: [],
///   validators: [minItems(1, 'Select at least one tag.')],
/// );
/// ```
String? Function(T) minItems<T extends Iterable<Object?>>(int n,
        [String? message]) =>
    (v) => v.length < n ? (message ?? 'Must have at least $n items.') : null;

/// Creates a validator that fails when an [Iterable] collection has more than [n] items.
///
/// Returns [message] (or `'Must have at most $n items.'` by default).
///
/// ```dart
/// final tagsField = BloomTypedFormField<List<String>>(
///   initialValue: [],
///   validators: [maxItems(5, 'Cannot select more than 5 tags.')],
/// );
/// ```
String? Function(T) maxItems<T extends Iterable<Object?>>(int n,
        [String? message]) =>
    (v) => v.length > n ? (message ?? 'Must have at most $n items.') : null;

/// Creates a validator that fails when an [Iterable] collection item count is outside [[minN], [maxN]].
///
/// Returns [message] (or `'Must have between $minN and $maxN items.'` by default).
///
/// ```dart
/// final attachments = BloomTypedFormField<List<String>>(
///   initialValue: [],
///   validators: [rangeItems(1, 3, 'Select between 1 and 3 items.')],
/// );
/// ```
String? Function(T) rangeItems<T extends Iterable<Object?>>(int minN, int maxN,
        [String? message]) =>
    (v) => (v.length < minN || v.length > maxN)
        ? (message ?? 'Must have between $minN and $maxN items.')
        : null;

/// Creates a validator for [BloomFileField] that fails when no file is selected.
///
/// Returns [message] (or `'Please select a file.'` by default).
///
/// ```dart
/// final resumeField = BloomFileField(
///   validators: [fileRequired('Please upload your resume.')],
/// );
/// ```
String? Function(List<BloomFile>) fileRequired([String? message]) =>
    (files) => files.isEmpty ? (message ?? 'Please select a file.') : null;

/// Creates a validator for [BloomFileField] that fails when any file exceeds [maxBytes].
///
/// Returns [message] (or `'File size exceeds maximum allowed limit of $maxBytes bytes.'` by default).
///
/// ```dart
/// final avatarField = BloomFileField(
///   validators: [maxFileSize(2 * 1024 * 1024, 'Avatar must be under 2MB.')],
/// );
/// ```
String? Function(List<BloomFile>) maxFileSize(int maxBytes, [String? message]) =>
    (files) => files.any((f) => f.size > maxBytes)
        ? (message ??
            'File size exceeds maximum allowed limit of $maxBytes bytes.')
        : null;

/// Creates a validator for [BloomFileField] that fails when the combined size of all files exceeds [maxBytes].
///
/// Returns [message] (or `'Total file size exceeds $maxBytes bytes.'` by default).
///
/// ```dart
/// final galleryField = BloomFileField(
///   multiple: true,
///   validators: [maxTotalFileSize(10 * 1024 * 1024, 'Total upload cannot exceed 10MB.')],
/// );
/// ```
String? Function(List<BloomFile>) maxTotalFileSize(int maxBytes,
        [String? message]) =>
    (files) {
      final total = files.fold<int>(0, (sum, f) => sum + f.size);
      return total > maxBytes
          ? (message ?? 'Total file size exceeds $maxBytes bytes.')
          : null;
    };

/// Creates a validator for [BloomFileField] that fails when fewer than [count] files are selected.
///
/// Returns [message] (or `'Please select at least $count files.'` by default).
///
/// ```dart
/// final docsField = BloomFileField(
///   multiple: true,
///   validators: [minFiles(2, 'Please upload at least 2 verification documents.')],
/// );
/// ```
String? Function(List<BloomFile>) minFiles(int count, [String? message]) =>
    (files) => files.length < count
        ? (message ?? 'Please select at least $count files.')
        : null;

/// Creates a validator for [BloomFileField] that fails when more than [count] files are selected.
///
/// Returns [message] (or `'Cannot select more than $count files.'` by default).
///
/// ```dart
/// final photosField = BloomFileField(
///   multiple: true,
///   validators: [maxFiles(5, 'Maximum 5 photos allowed.')],
/// );
/// ```
String? Function(List<BloomFile>) maxFiles(int count, [String? message]) =>
    (files) => files.length > count
        ? (message ?? 'Cannot select more than $count files.')
        : null;

/// Creates a validator for [BloomFileField] that fails when a file's extension is not in [extensions].
///
/// Comparison is case-insensitive. Extensions may be specified with or without leading dots (e.g. `['.pdf', 'png']`).
/// Returns [message] (or `'File extension "$ext" is not allowed. Allowed: ...'` by default).
///
/// ```dart
/// final resumeField = BloomFileField(
///   validators: [allowedExtensions(['.pdf', '.docx'])],
/// );
/// ```
String? Function(List<BloomFile>) allowedExtensions(List<String> extensions,
    [String? message]) {
  final lowerExts = extensions
      .map((e) => e.startsWith('.') ? e.toLowerCase() : '.$e'.toLowerCase())
      .toSet();
  return (files) {
    for (final file in files) {
      final ext = file.extension;
      if (ext.isEmpty || !lowerExts.contains(ext)) {
        return message ??
            'File extension "$ext" is not allowed. Allowed: ${extensions.join(', ')}.';
      }
    }
    return null;
  };
}

/// Creates a validator for [BloomFileField] that fails when a file's MIME type does not match [mimeTypes].
///
/// Supports exact MIME types (e.g. `'image/png'`) and wildcards (e.g. `'image/*'`).
/// Returns [message] (or `'MIME type "$fileType" is not allowed. Allowed: ...'` by default).
///
/// ```dart
/// final imageField = BloomFileField(
///   validators: [allowedMimeTypes(['image/png', 'image/jpeg', 'image/webp'])],
/// );
/// ```
String? Function(List<BloomFile>) allowedMimeTypes(List<String> mimeTypes,
    [String? message]) {
  final lowerTypes = mimeTypes.map((m) => m.toLowerCase()).toList();
  return (files) {
    for (final file in files) {
      final fileType = file.mimeType.toLowerCase();
      final matched = lowerTypes.any((allowed) {
        if (allowed.endsWith('/*')) {
          final prefix = allowed.substring(0, allowed.length - 1);
          return fileType.startsWith(prefix);
        }
        return fileType == allowed;
      });
      if (!matched) {
        return message ??
            'MIME type "$fileType" is not allowed. Allowed: ${mimeTypes.join(', ')}.';
      }
    }
    return null;
  };
}

// ─── Base Abstraction: BloomFormControl ───────────────────────────────────────

/// Abstract base contract for all reactive Bloom form controls.
///
/// Provides a unified reactive state surface across single-value inputs ([BloomFormField],
/// [BloomTypedFormField]), file attachments ([BloomFileField]), repeating collections
/// ([BloomFieldArray]), and nested sub-forms ([BloomFormGroup]).
///
/// Both browser DOM mounting and SSR evaluate these signals seamlessly.
///
/// ```dart
/// void inspectControl(BloomFormControl control) {
///   if (!control.isValid.value) {
///     print('Validation errors: ${control.errors.value}');
///   }
/// }
/// ```
abstract class BloomFormControl {
  /// Reactive signal containing validation error messages generated by [validate].
  Signal<List<String>> get errors;

  /// Reactive signal indicating whether user actions have modified the initial value.
  ///
  /// Declared as a [ReadonlySignal] so that composite controls ([BloomFieldArray],
  /// [BloomFormGroup]) can satisfy it with a `computed` that aggregates their
  /// children's dirty state. Leaf controls such as [BloomFormField] narrow it to a
  /// writable [Signal], which is a valid covariant override.
  ReadonlySignal<bool> get isDirty;

  /// Reactive signal indicating whether the user has interacted with or blurred this control.
  Signal<bool> get isTouched;

  /// Computed signal that evaluates to `true` when [errors] is empty and all children are valid.
  ReadonlySignal<bool> get isValid;

  /// Raw untyped value of the control used during form serialization and aggregation.
  dynamic get rawValue;

  /// Validates this control and any child controls, updating [errors].
  ///
  /// Returns `true` if valid and [errors] is empty; `false` otherwise.
  bool validate();

  /// Resets this control to its initial state, clearing [errors], [isDirty], and [isTouched].
  void reset();

  /// Marks this control as touched (e.g. on blur or user interaction).
  void touch();
}

// ─── BloomFormField ───────────────────────────────────────────────────────────

/// Reactive state controller for an individual string form input field.
///
/// Tracks input state, error messages, dirty/touched flags, and validation status
/// using fine-grained `signals` primitives.
///
/// ### Validation Timing
/// Setting the field value via [setValue] updates [value] and marks [isDirty] as `true`,
/// but does **not** run validators automatically. Validation runs synchronously when
/// [validate] is explicitly invoked (for example during [BloomForm.submit] or on an
/// input blur event via `on: {'blur': (_) => field.validate()}`).
///
/// ### Reactive State
/// - [value]: Current string value as a `Signal<String>`.
/// - [errors]: List of active validation error strings as a `Signal<List<String>>`.
/// - [isDirty]: `true` if [setValue] has been called since instantiation or [reset].
/// - [isTouched]: `true` after [touch] is called (e.g. on blur).
/// - [isValid]: Computed `ReadonlySignal<bool>` that evaluates to `true` when [errors] is empty.
///
/// ```dart
/// final username = BloomFormField(
///   initialValue: '',
///   validators: [required(), minLength(3)],
/// );
///
/// BloomNode usernameInput() => Div(
///   children: [
///     Input(
///       attrs: {'value': username.value.value, 'placeholder': 'Username'},
///       on: {
///         'input': (e) => username.setValue(e.value ?? ''),
///         'blur': (_) {
///           username.touch();
///           username.validate();
///         },
///       },
///     ),
///     Live(() => username.errors.value.isNotEmpty
///         ? Span(className: 'error', text: username.errors.value.first)
///         : const Fragment([])),
///   ],
/// );
/// ```
class BloomFormField implements BloomFormControl {
  final String _initialValue;

  /// Ordered list of validator callbacks evaluated on [validate].
  final List<String? Function(String)> validators;

  /// Reactive signal containing the current field value.
  late final Signal<String> value;

  /// Reactive signal containing validation error messages generated by [validate].
  @override
  late final Signal<List<String>> errors;

  /// Reactive signal indicating whether [setValue] has modified the initial value.
  @override
  late final Signal<bool> isDirty;

  /// Reactive signal indicating whether the user has interacted with or blurred this field.
  @override
  late final Signal<bool> isTouched;

  /// Computed signal that evaluates to `true` when [errors] is empty.
  @override
  late final ReadonlySignal<bool> isValid;

  /// Creates a form field controller with optional [initialValue] and [validators].
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

  /// Untyped access to the string value.
  @override
  dynamic get rawValue => value.value;

  /// Updates the field's [value] and marks [isDirty] as `true`.
  ///
  /// Note: Does not automatically trigger [validate]. Call [validate] explicitly
  /// if immediate validation feedback is desired.
  void setValue(String newValue) {
    value.value = newValue;
    isDirty.value = true;
  }

  /// Marks [isTouched] as `true` to indicate user interaction (e.g. on blur).
  @override
  void touch() => isTouched.value = true;

  /// Runs all [validators] against the current [value] and updates [errors].
  ///
  /// Returns `true` if all validators passed and [errors] is empty; `false` otherwise.
  @override
  bool validate() {
    final errs = <String>[];
    for (final v in validators) {
      final err = v(value.value);
      if (err != null) errs.add(err);
    }
    errors.value = errs;
    return errs.isEmpty;
  }

  /// Resets [value] back to its initial value, clears [errors], and sets [isDirty] and [isTouched] to `false`.
  @override
  void reset() {
    value.value = _initialValue;
    errors.value = [];
    isDirty.value = false;
    isTouched.value = false;
  }
}

// ─── BloomTypedFormField<T> ───────────────────────────────────────────────────

/// Reactive state controller for an individual strongly-typed form input field.
///
/// Manages arbitrary value types [T] such as [int], [double], [bool], [DateTime],
/// enums, or custom domain models with fine-grained reactivity.
///
/// Both browser DOM mounting and SSR evaluate these signals seamlessly.
///
/// ```dart
/// final ageField = BloomTypedFormField<int>(
///   initialValue: 18,
///   validators: [min(13, 'Must be at least 13 years old.')],
/// );
///
/// ageField.setValue(21);
/// ```
class BloomTypedFormField<T> implements BloomFormControl {
  final T _initialValue;

  /// Ordered list of validator callbacks evaluated on [validate].
  final List<String? Function(T)> validators;

  /// Reactive signal containing the current typed field value.
  late final Signal<T> value;

  /// Reactive signal containing validation error messages generated by [validate].
  @override
  late final Signal<List<String>> errors;

  /// Reactive signal indicating whether [setValue] has modified the initial value.
  @override
  late final Signal<bool> isDirty;

  /// Reactive signal indicating whether the user has interacted with or blurred this field.
  @override
  late final Signal<bool> isTouched;

  /// Computed signal that evaluates to `true` when [errors] is empty.
  @override
  late final ReadonlySignal<bool> isValid;

  /// Creates a typed form field controller with [initialValue] and optional [validators].
  BloomTypedFormField({
    required T initialValue,
    this.validators = const [],
  }) : _initialValue = initialValue {
    value = signal<T>(initialValue);
    errors = signal<List<String>>([]);
    isDirty = signal(false);
    isTouched = signal(false);
    isValid = computed(() => errors.value.isEmpty);
  }

  /// Untyped access to the typed value.
  @override
  dynamic get rawValue => value.value;

  /// Updates the field's [value] and marks [isDirty] as `true`.
  void setValue(T newValue) {
    value.value = newValue;
    isDirty.value = true;
  }

  /// Marks [isTouched] as `true` to indicate user interaction (e.g. on blur).
  @override
  void touch() => isTouched.value = true;

  /// Runs all [validators] against the current [value] and updates [errors].
  ///
  /// Returns `true` if all validators passed and [errors] is empty; `false` otherwise.
  @override
  bool validate() {
    final errs = <String>[];
    for (final v in validators) {
      final err = v(value.value);
      if (err != null) errs.add(err);
    }
    errors.value = errs;
    return errs.isEmpty;
  }

  /// Resets [value] back to its initial value, clears [errors], and sets [isDirty] and [isTouched] to `false`.
  @override
  void reset() {
    value.value = _initialValue;
    errors.value = [];
    isDirty.value = false;
    isTouched.value = false;
  }
}

/// Generic shorthand alias for [BloomTypedFormField].
typedef BloomField<T> = BloomTypedFormField<T>;

// ─── BloomFile & BloomFileField ───────────────────────────────────────────────

/// Platform-neutral file descriptor for file inputs and attachments.
///
/// Keeps `form.dart` pure Dart without requiring browser DOM `package:web` imports,
/// ensuring safe usage in Server-Side Rendering (SSR) and Dart VM unit tests.
/// In browser execution, [rawFile] holds an opaque reference to the browser's native `web.File`.
///
/// ```dart
/// final document = BloomFile(
///   name: 'specs.pdf',
///   size: 1024 * 1024,
///   mimeType: 'application/pdf',
/// );
/// ```
class BloomFile {
  /// The filename without path (e.g. `'photo.png'`).
  final String name;

  /// The file size in bytes.
  final int size;

  /// The MIME media type (e.g. `'image/png'`, `'application/pdf'`).
  final String mimeType;

  /// Timestamp of when the file was last modified, if available.
  final DateTime? lastModified;

  /// Opaque handle to the underlying platform file instance (e.g. `web.File` in browser DOM).
  ///
  /// Untyped ([Object]?) to avoid DOM dependencies during SSR and VM tests.
  final Object? rawFile;

  /// Creates a platform-neutral [BloomFile] descriptor.
  const BloomFile({
    required this.name,
    this.size = 0,
    this.mimeType = '',
    this.lastModified,
    this.rawFile,
  });

  /// Returns the lowercase file extension including the leading period (e.g. `'.png'`),
  /// or an empty string if no extension is present.
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot != -1 ? name.substring(dot).toLowerCase() : '';
  }

  @override
  String toString() =>
      'BloomFile(name: $name, size: $size, mimeType: $mimeType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomFile &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          size == other.size &&
          mimeType == other.mimeType &&
          lastModified == other.lastModified &&
          rawFile == other.rawFile;

  @override
  int get hashCode =>
      Object.hash(name, size, mimeType, lastModified, rawFile);
}

/// Reactive controller for `<input type="file">` file selection fields.
///
/// Holds the list of selected [BloomFile] instances reactively and supports single
/// or multiple selection modes along with dedicated file validators (e.g. [maxFileSize],
/// [allowedExtensions], [allowedMimeTypes], [minFiles], [maxFiles]).
///
/// Safe for both browser DOM mounting and SSR rendering.
///
/// ```dart
/// final avatarField = BloomFileField(
///   multiple: false,
///   validators: [
///     fileRequired('Please choose an avatar image.'),
///     maxFileSize(2 * 1024 * 1024, 'Avatar must be smaller than 2MB.'),
///     allowedExtensions(['.png', '.jpg', '.webp']),
///   ],
/// );
/// ```
class BloomFileField implements BloomFormControl {
  final List<BloomFile> _initialValue;

  /// Whether this field accepts multiple files.
  final bool multiple;

  /// Ordered list of validator callbacks evaluated on [validate].
  final List<String? Function(List<BloomFile>)> validators;

  /// Reactive signal containing the list of currently selected [BloomFile] items.
  late final Signal<List<BloomFile>> value;

  /// Reactive signal containing validation error messages generated by [validate].
  @override
  late final Signal<List<String>> errors;

  /// Reactive signal indicating whether the file selection has been modified.
  @override
  late final Signal<bool> isDirty;

  /// Reactive signal indicating whether the user has interacted with this field.
  @override
  late final Signal<bool> isTouched;

  /// Computed signal that evaluates to `true` when [errors] is empty.
  @override
  late final ReadonlySignal<bool> isValid;

  /// Creates a reactive file input controller.
  BloomFileField({
    List<BloomFile> initialValue = const [],
    this.multiple = false,
    this.validators = const [],
  }) : _initialValue = List.unmodifiable(initialValue) {
    value = signal<List<BloomFile>>(List.unmodifiable(initialValue));
    errors = signal<List<String>>([]);
    isDirty = signal(false);
    isTouched = signal(false);
    isValid = computed(() => errors.value.isEmpty);
  }

  /// Convenience getter returning the first selected [BloomFile], or `null` if empty.
  BloomFile? get file => value.value.isEmpty ? null : value.value.first;

  /// Returns the current list of selected files.
  List<BloomFile> get files => value.value;

  /// Untyped access to the selected files list.
  @override
  dynamic get rawValue => value.value;

  /// Updates the selected files and marks [isDirty] as `true`.
  void setFiles(List<BloomFile> newFiles) {
    value.value = List.unmodifiable(newFiles);
    isDirty.value = true;
  }

  /// Sets a single selected file (or clears selection if `null`) and marks [isDirty] as `true`.
  void setFile(BloomFile? singleFile) {
    setFiles(singleFile == null ? const [] : [singleFile]);
  }

  /// Clears all selected files and marks [isDirty] as `true`.
  void clear() => setFiles(const []);

  /// Marks [isTouched] as `true` to indicate user interaction (e.g. on change or blur).
  @override
  void touch() => isTouched.value = true;

  /// Runs all [validators] against the current [value] and updates [errors].
  ///
  /// Returns `true` if all validators passed and [errors] is empty; `false` otherwise.
  @override
  bool validate() {
    final errs = <String>[];
    for (final v in validators) {
      final err = v(value.value);
      if (err != null) errs.add(err);
    }
    errors.value = errs;
    return errs.isEmpty;
  }

  /// Resets the selected files back to initial value and clears [errors], [isDirty], and [isTouched].
  @override
  void reset() {
    value.value = _initialValue;
    errors.value = [];
    isDirty.value = false;
    isTouched.value = false;
  }
}

// ─── BloomFieldArray ──────────────────────────────────────────────────────────

/// Reactive controller for a repeating collection of child form controls or sub-forms.
///
/// Supports adding, removing, and reordering child items reactively. Adding or removing
/// entries automatically updates the [fields] signal, notifying reactive boundaries.
///
/// ```dart
/// final todoItems = BloomFieldArray<BloomFormField>(
///   initialValues: [
///     BloomFormField(initialValue: 'First task'),
///   ],
/// );
///
/// todoItems.add(BloomFormField(initialValue: 'Second task'));
/// ```
class BloomFieldArray<T extends BloomFormControl> implements BloomFormControl {
  final List<T> Function()? _itemFactory;
  final List<T> _initialControls;

  /// Reactive signal holding the ordered list of child controls.
  late final Signal<List<T>> fields;

  /// Reactive signal containing array-level validation errors.
  @override
  late final Signal<List<String>> errors;

  final Signal<bool> _arrayDirty = signal(false);

  /// Reactive signal indicating whether this array has been interacted with.
  @override
  late final Signal<bool> isTouched;

  /// Computed signal indicating whether any child is dirty or the array membership has changed.
  @override
  late final ReadonlySignal<bool> isDirty;

  /// Computed signal returning `true` when all child controls are valid and array-level [errors] is empty.
  @override
  late final ReadonlySignal<bool> isValid;

  /// Optional array-level validators (e.g. [minItems], [maxItems]).
  final List<String? Function(List<T>)> validators;

  /// Creates a reactive field array initialized with [initialValues] or an optional [itemFactory].
  BloomFieldArray({
    List<T> initialValues = const [],
    List<T> Function()? itemFactory,
    this.validators = const [],
  })  : _itemFactory = itemFactory,
        _initialControls = List.unmodifiable(initialValues) {
    fields = signal<List<T>>(List.of(initialValues));
    errors = signal<List<String>>([]);
    isTouched = signal(false);

    isDirty = computed(() =>
        _arrayDirty.value ||
        fields.value.any((control) => control.isDirty.value));

    isValid = computed(() =>
        errors.value.isEmpty &&
        fields.value.every((control) => control.isValid.value));
  }

  /// Returns the current number of child controls in the array.
  int get length => fields.value.length;

  /// Returns the child control at [index].
  T operator [](int index) => fields.value[index];

  /// Returns the raw untyped list of child control values.
  @override
  dynamic get rawValue => fields.value.map((c) => c.rawValue).toList();

  /// Appends [control] to the end of the array.
  void add(T control) {
    final current = List<T>.of(fields.value);
    current.add(control);
    fields.value = current;
    _arrayDirty.value = true;
  }

  /// Inserts [control] at position [index].
  void insert(int index, T control) {
    final current = List<T>.of(fields.value);
    current.insert(index, control);
    fields.value = current;
    _arrayDirty.value = true;
  }

  /// Removes and returns the control at [index].
  T removeAt(int index) {
    final current = List<T>.of(fields.value);
    final removed = current.removeAt(index);
    fields.value = current;
    _arrayDirty.value = true;
    return removed;
  }

  /// Removes the first occurrence of [control] from the array.
  bool remove(T control) {
    final current = List<T>.of(fields.value);
    final result = current.remove(control);
    if (result) {
      fields.value = current;
      _arrayDirty.value = true;
    }
    return result;
  }

  /// Moves a control from [oldIndex] to [newIndex].
  void move(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final current = List<T>.of(fields.value);
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    fields.value = current;
    _arrayDirty.value = true;
  }

  /// Clears all child controls from the array.
  void clear() {
    fields.value = [];
    _arrayDirty.value = true;
  }

  /// Marks this array and all its child controls as touched.
  @override
  void touch() {
    isTouched.value = true;
    for (final child in fields.value) {
      child.touch();
    }
  }

  /// Runs array-level [validators] and triggers [validate] on every child control.
  ///
  /// Returns `true` if all child controls and array-level validators pass; `false` otherwise.
  @override
  bool validate() {
    var allValid = true;
    final errs = <String>[];
    for (final v in validators) {
      final err = v(fields.value);
      if (err != null) errs.add(err);
    }
    errors.value = errs;
    if (errs.isNotEmpty) allValid = false;

    for (final child in fields.value) {
      final valid = child.validate();
      if (!valid) allValid = false;
    }
    return allValid;
  }

  /// Resets the array back to its initial controls and resets each child.
  @override
  void reset() {
    if (_itemFactory != null) {
      fields.value = _itemFactory();
    } else {
      fields.value = List.of(_initialControls);
      for (final child in fields.value) {
        child.reset();
      }
    }
    errors.value = [];
    _arrayDirty.value = false;
    isTouched.value = false;
  }
}

/// Alias for [BloomFieldArray] representing a repeating list of form controls.
typedef BloomFormArray<T extends BloomFormControl> = BloomFieldArray<T>;

// ─── BloomFormGroup ───────────────────────────────────────────────────────────

/// Reactive controller for a nested group of named form controls.
///
/// Implements [BloomFormControl] so nested groups can be composed hierarchically
/// within [BloomForm] or [BloomFieldArray].
///
/// ```dart
/// final addressGroup = BloomFormGroup({
///   'street': BloomFormField(validators: [required()]),
///   'city': BloomFormField(validators: [required()]),
/// });
/// ```
class BloomFormGroup implements BloomFormControl {
  final Map<String, BloomFormControl> _fields;

  /// Reactive signal containing group-level validation errors.
  @override
  late final Signal<List<String>> errors;

  /// Reactive signal indicating whether this group has been touched.
  @override
  late final Signal<bool> isTouched;

  /// Computed signal returning `true` when every child control's `isValid` is `true`
  /// and group-level [errors] is empty.
  @override
  late final ReadonlySignal<bool> isValid;

  /// Computed signal returning `true` when at least one child control's `isDirty` is `true`.
  @override
  late final ReadonlySignal<bool> isDirty;

  /// Optional group-level validators evaluated against the raw value map.
  final List<String? Function(Map<String, dynamic>)> validators;

  /// Creates a [BloomFormGroup] managing the given map of named [fields].
  BloomFormGroup(
    Map<String, BloomFormControl> fields, {
    this.validators = const [],
  }) : _fields = fields {
    errors = signal<List<String>>([]);
    isTouched = signal(false);
    isValid = computed(() =>
        errors.value.isEmpty && _fields.values.every((f) => f.isValid.value));
    isDirty = computed(() => _fields.values.any((f) => f.isDirty.value));
  }

  /// Map of all registered child controls.
  Map<String, BloomFormControl> get fields => _fields;

  /// Returns the registered control under [name] typed as [T].
  ///
  /// Throws [StateError] if no control with [name] exists or if it cannot be cast to [T].
  T getControl<T extends BloomFormControl>(String name) {
    final field = _fields[name];
    if (field == null) {
      throw StateError(
          'BloomFormGroup: No field registered with name "$name".');
    }
    if (field is! T) {
      throw StateError(
          'BloomFormGroup: Field "$name" is of type ${field.runtimeType}, expected $T.');
    }
    return field;
  }

  /// Returns the [BloomFormField] registered under [name].
  ///
  /// Throws [StateError] if no field with [name] exists or if it is not a [BloomFormField].
  BloomFormField getField(String name) => getControl<BloomFormField>(name);

  /// Untyped structured map of all child values.
  @override
  Map<String, dynamic> get rawValue => {
        for (final entry in _fields.entries) entry.key: entry.value.rawValue,
      };

  /// Snapshot map of all child values keyed by field name.
  Map<String, dynamic> get rawValues => rawValue;

  /// Snapshot map of string representations of child values.
  Map<String, String> get values => {
        for (final entry in _fields.entries)
          entry.key: entry.value is BloomFormField
              ? (entry.value as BloomFormField).value.value
              : entry.value.rawValue?.toString() ?? '',
      };

  /// Returns the string value of the field registered under [name].
  String getValue(String name) {
    final field = _fields[name];
    if (field == null) {
      throw StateError(
          'BloomFormGroup: No field registered with name "$name".');
    }
    if (field is BloomFormField) return field.value.value;
    return field.rawValue?.toString() ?? '';
  }

  /// Marks this group and all its child controls as touched.
  @override
  void touch() {
    isTouched.value = true;
    for (final field in _fields.values) {
      field.touch();
    }
  }

  /// Runs group-level [validators] and [validate] on every child control.
  ///
  /// Returns `true` if all child controls and group validators pass; `false` otherwise.
  @override
  bool validate() {
    var allValid = true;
    final errs = <String>[];
    final currentValues = rawValue;
    for (final v in validators) {
      final err = v(currentValues);
      if (err != null) errs.add(err);
    }
    errors.value = errs;
    if (errs.isNotEmpty) allValid = false;

    for (final field in _fields.values) {
      final valid = field.validate();
      if (!valid) allValid = false;
    }
    return allValid;
  }

  /// Resets all child controls to their initial values and clears [errors] and [isTouched].
  @override
  void reset() {
    for (final field in _fields.values) {
      field.reset();
    }
    errors.value = [];
    isTouched.value = false;
  }
}

/// Alias for [BloomFormGroup] representing a nested sub-form.
typedef BloomSubForm = BloomFormGroup;

/// Alias for [BloomFormGroup] representing a nested sub-form.
typedef BloomNestedForm = BloomFormGroup;

// ─── BloomForm ────────────────────────────────────────────────────────────────

/// Reactive controller for a collection of named form controls.
///
/// Coordinates cross-field validation, dirty tracking, submission lifecycle,
/// and form reset operations across mixed field types (strings, numbers, booleans,
/// files, field arrays, and nested sub-forms).
///
/// ### Submission Lifecycle
/// Calling [submit] or [submitRaw] executes the following sequence:
/// 1. Calls [validate] across all registered controls.
/// 2. If any control fails validation, submission halts immediately and callback is not called.
/// 3. If validation succeeds, [isSubmitting] is set to `true`.
/// 4. Awaits the callback with a snapshot of values.
/// 5. In a `finally` block, resets [isSubmitting] back to `false`.
///
/// ```dart
/// final profileForm = BloomForm({
///   'username': BloomFormField(validators: [required(), minLength(3)]),
///   'age': BloomTypedFormField<int>(initialValue: 25, validators: [min(18)]),
///   'avatar': BloomFileField(validators: [fileRequired()]),
///   'agree': BloomTypedFormField<bool>(initialValue: false, validators: [requiredTrue()]),
///   'skills': BloomFieldArray<BloomFormField>(
///     initialValues: [BloomFormField(initialValue: 'Dart')],
///   ),
/// });
///
/// await profileForm.submitRaw((data) async {
///   print('Submitted data: $data');
/// });
/// ```
class BloomForm {
  final Map<String, BloomFormControl> _fields;

  /// Computed signal returning `true` when every registered field's [BloomFormControl.isValid] is `true`.
  late final ReadonlySignal<bool> isValid;

  /// Computed signal returning `true` when at least one registered field's [BloomFormControl.isDirty] is `true`.
  late final ReadonlySignal<bool> isDirty;

  /// Reactive signal indicating whether an asynchronous submit handler is currently running.
  final Signal<bool> isSubmitting = signal(false);

  /// Creates a [BloomForm] controller managing the provided map of named [fields].
  BloomForm(Map<String, BloomFormControl> fields) : _fields = fields {
    isValid = computed(() => _fields.values.every((f) => f.isValid.value));
    isDirty = computed(() => _fields.values.any((f) => f.isDirty.value));
  }

  /// Map of all registered controls in the form.
  Map<String, BloomFormControl> get fields => _fields;

  /// Returns the registered control under [name] typed as [T].
  ///
  /// Throws [StateError] if no control with [name] exists or if it is not of type [T].
  T getControl<T extends BloomFormControl>(String name) {
    final field = _fields[name];
    if (field == null) {
      throw StateError('BloomForm: No field registered with name "$name".');
    }
    if (field is! T) {
      throw StateError(
          'BloomForm: Field "$name" is of type ${field.runtimeType}, expected $T.');
    }
    return field;
  }

  /// Returns the [BloomFormField] registered under [name].
  ///
  /// Throws [StateError] if no field with [name] exists in this form or if it is not a [BloomFormField].
  BloomFormField getField(String name) {
    final field = _fields[name];
    if (field == null) {
      throw StateError('BloomForm: No field registered with name "$name".');
    }
    if (field is! BloomFormField) {
      throw StateError(
          'BloomForm: Field "$name" is of type ${field.runtimeType}, expected BloomFormField.');
    }
    return field;
  }

  /// Returns the current string value of the field registered under [name].
  String getValue(String name) {
    final field = _fields[name];
    if (field == null) {
      throw StateError('BloomForm: No field registered with name "$name".');
    }
    if (field is BloomFormField) {
      return field.value.value;
    }
    final raw = field.rawValue;
    return raw?.toString() ?? '';
  }

  /// Returns a snapshot map of all current field string values keyed by field name.
  Map<String, String> get values => {
        for (final entry in _fields.entries)
          entry.key: entry.value is BloomFormField
              ? (entry.value as BloomFormField).value.value
              : entry.value.rawValue?.toString() ?? '',
      };

  /// Returns a structured map containing untyped/raw values of all registered fields.
  Map<String, dynamic> get rawValues => {
        for (final entry in _fields.entries) entry.key: entry.value.rawValue,
      };

  /// Alias for [rawValues] returning the structured values of all registered fields.
  Map<String, dynamic> get data => rawValues;

  /// Marks all registered fields as touched.
  void touch() {
    for (final field in _fields.values) {
      field.touch();
    }
  }

  /// Runs `validate()` on every registered field.
  ///
  /// Returns `true` if all fields passed validation; `false` if one or more fields failed.
  bool validate() {
    var allValid = true;
    for (final field in _fields.values) {
      final valid = field.validate();
      if (!valid) allValid = false;
    }
    return allValid;
  }

  /// Validates all fields and executes [onSubmit] if validation succeeds.
  ///
  /// If validation fails, halts immediately. If validation passes, sets [isSubmitting]
  /// to `true`, awaits [onSubmit] with string [values], and ensures [isSubmitting]
  /// is reset to `false` upon completion.
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

  /// Validates all fields and executes [onSubmit] with structured [rawValues] if validation succeeds.
  ///
  /// Yields raw/untyped values including files, arrays, numbers, booleans, and nested sub-forms.
  Future<void> submitRaw(
      Future<void> Function(Map<String, dynamic> values) onSubmit) async {
    if (!validate()) return;
    isSubmitting.value = true;
    try {
      await onSubmit(rawValues);
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Alias for [submitRaw] taking structured values.
  Future<void> submitData(
      Future<void> Function(Map<String, dynamic> values) onSubmit) =>
      submitRaw(onSubmit);

  /// Resets all registered fields to their initial values and clears [isSubmitting].
  void reset() {
    for (final field in _fields.values) {
      field.reset();
    }
    isSubmitting.value = false;
  }
}

