/// Typed DOM event abstraction that decouples event handlers from the browser runtime.
///
/// Handlers attached to [ElNode.on] receive a [BloomEvent] across both browser
/// execution (populated from native DOM events via JS interop) and VM test
/// environments (created via synthetic test factories like [BloomEvent.fakeClick]).
///
/// In the browser (`mount.dart`), event properties are extracted opportunistically
/// from the underlying JavaScript event object. Depending on whether the event is an
/// input, mouse, keyboard, or drag-and-drop event, many properties will be `null`.
/// For example, [value] and [checked] are populated for `<input>`, `<textarea>`,
/// and `<select>` elements, [key] and [code] for keyboard events, and [clientX]
/// and [clientY] for mouse/pointer events.
///
/// ```dart
/// Input(
///   attrs: {'type': 'text', 'placeholder': 'Type and press Enter...'},
///   on: {
///     'input': (event) {
///       final text = event.value ?? '';
///       query.value = text;
///     },
///     'keydown': (event) {
///       if (event.key == 'Enter' && !event.shiftKey) {
///         event.preventDefault();
///         submitQuery();
///       }
///     },
///   },
/// )
/// ```
class BloomEvent {
  /// The DOM event type string (e.g. `'click'`, `'input'`, `'change'`, `'submit'`, `'keydown'`).
  final String type;

  /// The string value extracted from the event target (`target.value`).
  ///
  /// Populated for input-like elements (`<input>`, `<textarea>`, `<select>`).
  /// Remains `null` for non-input elements or synthetic events without a value.
  final String? value;

  /// The boolean checked state extracted from the event target (`target.checked`).
  ///
  /// Populated for checkbox and radio inputs (`<input type="checkbox">`, `<input type="radio">`).
  /// Remains `null` for other element types.
  final bool? checked;

  /// The raw JavaScript DOM target element in browser execution.
  ///
  /// Typed as [Object]? (underlying `JSAny?`) so that the core framework
  /// remains VM-compatible without requiring `package:web` imports in pure Dart
  /// environments. Evaluates to `null` in VM test fixtures unless explicitly provided.
  final Object? rawTarget;

  // ── Keyboard ────────────────────────────────────────────────────────
  /// The printable key value of the pressed key (e.g. `'Enter'`, `'Escape'`, `'a'`, `'ArrowDown'`).
  ///
  /// Populated for keyboard events (`keydown`, `keyup`, `keypress`). Remains `null` for non-keyboard events.
  final String? key;

  /// The physical key code identifier on the keyboard (e.g. `'KeyA'`, `'Enter'`, `'Space'`).
  ///
  /// Populated for keyboard events. Remains `null` for non-keyboard events.
  final String? code;

  /// Whether the Shift modifier key was active during this event.
  final bool shiftKey;

  /// Whether the Control modifier key was active during this event.
  final bool ctrlKey;

  /// Whether the Alt / Option modifier key was active during this event.
  final bool altKey;

  /// Whether the Meta / Command / Windows modifier key was active during this event.
  final bool metaKey;

  // ── Mouse / Pointer ─────────────────────────────────────────────────
  /// Horizontal coordinate of the pointer within the application's viewport in pixels.
  ///
  /// Populated for mouse and pointer events (e.g. `click`, `mousemove`, `pointerdown`).
  /// Remains `null` for other event types.
  final double? clientX;

  /// Vertical coordinate of the pointer within the application's viewport in pixels.
  ///
  /// Populated for mouse and pointer events. Remains `null` for other event types.
  final double? clientY;

  /// Horizontal offset of the mouse pointer relative to the target element's padding edge.
  ///
  /// Populated for mouse and pointer events. Remains `null` for other event types.
  final double? offsetX;

  /// Vertical offset of the mouse pointer relative to the target element's padding edge.
  ///
  /// Populated for mouse and pointer events. Remains `null` for other event types.
  final double? offsetY;

  /// The mouse button that triggered the event: `0` for primary/left, `1` for auxiliary/middle, `2` for secondary/right.
  ///
  /// Populated for mouse and pointer events. Remains `null` for other event types.
  final int? button;

  // ── File / Drag ─────────────────────────────────────────────────────
  /// File names for file input changes (`<input type="file">`) or drag-and-drop drops.
  ///
  /// Populated when file selection occurs in the browser. Remains `null` otherwise.
  final List<String>? files;

  /// Text data payload associated with HTML5 drag-and-drop events.
  ///
  /// Populated during drag-and-drop operations (`dragover`, `drop`). Remains `null` otherwise.
  final String? dataTransfer;

  final void Function()? _preventDefaultFn;
  final void Function()? _stopPropagationFn;

  bool _defaultPrevented = false;
  bool _propagationStopped = false;

  /// Creates a new [BloomEvent] descriptor with the given properties and lifecycle callbacks.
  BloomEvent({
    required this.type,
    this.value,
    this.checked,
    this.rawTarget,
    this.key,
    this.code,
    this.shiftKey = false,
    this.ctrlKey = false,
    this.altKey = false,
    this.metaKey = false,
    this.clientX,
    this.clientY,
    this.offsetX,
    this.offsetY,
    this.button,
    this.files,
    this.dataTransfer,
    void Function()? preventDefaultFn,
    void Function()? stopPropagationFn,
  })  : _preventDefaultFn = preventDefaultFn,
        _stopPropagationFn = stopPropagationFn;

  /// Prevents the browser's default action for this event.
  ///
  /// Sets [defaultPrevented] to `true` and invokes the underlying DOM event's
  /// `preventDefault()` when running in a browser environment.
  void preventDefault() {
    _defaultPrevented = true;
    _preventDefaultFn?.call();
  }

  /// Stops propagation (bubbling) of this event up the DOM tree.
  ///
  /// Sets [propagationStopped] to `true` and invokes the underlying DOM event's
  /// `stopPropagation()` when running in a browser environment.
  void stopPropagation() {
    _propagationStopped = true;
    _stopPropagationFn?.call();
  }

  /// Whether [preventDefault] has been called on this event.
  bool get defaultPrevented => _defaultPrevented;

  /// Whether [stopPropagation] has been called on this event.
  bool get propagationStopped => _propagationStopped;

  /// Creates a synthetic click [BloomEvent] for VM unit testing without a browser DOM.
  ///
  /// ```dart
  /// final button = Button(
  ///   text: 'Increment',
  ///   on: {'click': (e) => count.value++},
  /// );
  /// button.on?['click']?.call(BloomEvent.fakeClick());
  /// ```
  factory BloomEvent.fakeClick() => BloomEvent(type: 'click');

  /// Creates a synthetic input [BloomEvent] carrying [value] for VM unit testing.
  ///
  /// ```dart
  /// final input = Input(
  ///   on: {'input': (e) => username.value = e.value ?? ''},
  /// );
  /// input.on?['input']?.call(BloomEvent.fakeInput('antigravity'));
  /// ```
  factory BloomEvent.fakeInput(String value) =>
      BloomEvent(type: 'input', value: value);

  /// Creates a synthetic change [BloomEvent] carrying [value] or [checked] for VM unit testing.
  ///
  /// ```dart
  /// final checkbox = Input(
  ///   attrs: {'type': 'checkbox'},
  ///   on: {'change': (e) => agree.value = e.checked ?? false},
  /// );
  /// checkbox.on?['change']?.call(BloomEvent.fakeChange(checked: true));
  /// ```
  factory BloomEvent.fakeChange({String? value, bool? checked}) =>
      BloomEvent(type: 'change', value: value, checked: checked);

  /// Creates a generic synthetic [BloomEvent] with [type] and optional [value] for VM unit testing.
  ///
  /// ```dart
  /// final form = Form(
  ///   on: {'submit': (e) => e.preventDefault()},
  /// );
  /// form.on?['submit']?.call(BloomEvent.fake('submit'));
  /// ```
  factory BloomEvent.fake(String type, {String? value}) =>
      BloomEvent(type: type, value: value);

  /// Creates a synthetic keyboard [BloomEvent] with [key] and optional [code] for VM unit testing.
  ///
  /// ```dart
  /// final handler = (BloomEvent e) {
  ///   if (e.key == 'Escape') isOpen.value = false;
  /// };
  /// handler(BloomEvent.fakeKeyDown('Escape'));
  /// ```
  factory BloomEvent.fakeKeyDown(String key, {String? code}) =>
      BloomEvent(type: 'keydown', key: key, code: code ?? key);

  /// Creates a synthetic mouse [BloomEvent] with [x] and [y] viewport coordinates for VM unit testing.
  ///
  /// ```dart
  /// final handler = (BloomEvent e) => lastPos.value = '${e.clientX},${e.clientY}';
  /// handler(BloomEvent.fakeMouseMove(120, 80));
  /// ```
  factory BloomEvent.fakeMouseMove(double x, double y) =>
      BloomEvent(type: 'mousemove', clientX: x, clientY: y);
}

/// Callback handler signature for Bloom DOM events.
///
/// Handlers receive a [BloomEvent] wrapping the dispatched user event.
typedef BloomEventHandler = void Function(BloomEvent event);
