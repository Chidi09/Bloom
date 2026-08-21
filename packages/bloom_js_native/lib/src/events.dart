/// Typed event abstraction that decouples handlers from the browser.
/// Handlers receive a [BloomEvent] so they remain VM-testable without a DOM.
class BloomEvent {
  /// DOM event type, e.g. "click", "input", "change", "submit".
  final String type;

  /// The `value` of the event target (for input/select/textarea).
  final String? value;

  /// The checked state (for checkbox/radio inputs).
  final bool? checked;

  /// Raw target element if available (browser only; typed `Object?` so the
  /// core library stays loadable on the VM).
  final Object? rawTarget;

  // ── Keyboard ────────────────────────────────────────────────────────
  /// The value of the key pressed, e.g. "Enter", "Escape", "a".
  final String? key;

  /// Physical key code on the keyboard, e.g. "KeyA", "Enter".
  final String? code;

  /// Whether the Shift key was active during the event.
  final bool shiftKey;

  /// Whether the Control key was active during the event.
  final bool ctrlKey;

  /// Whether the Alt/Option key was active during the event.
  final bool altKey;

  /// Whether the Meta/Command/Windows key was active during the event.
  final bool metaKey;

  // ── Mouse / Pointer ─────────────────────────────────────────────────
  /// Horizontal coordinate within the application's viewport.
  final double? clientX;

  /// Vertical coordinate within the application's viewport.
  final double? clientY;

  /// Horizontal offset of the mouse pointer relative to the target element.
  final double? offsetX;

  /// Vertical offset of the mouse pointer relative to the target element.
  final double? offsetY;

  /// Mouse button pressed: 0 for main/left, 1 for auxiliary/middle, 2 for secondary/right.
  final int? button;

  // ── File / Drag ─────────────────────────────────────────────────────
  /// File names for file input changes or drops.
  final List<String>? files;

  /// Text data for drag-and-drop events.
  final String? dataTransfer;

  final void Function()? _preventDefaultFn;
  final void Function()? _stopPropagationFn;

  bool _defaultPrevented = false;
  bool _propagationStopped = false;

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

  /// Prevent the browser default action.
  void preventDefault() {
    _defaultPrevented = true;
    _preventDefaultFn?.call();
  }

  /// Stop event bubbling.
  void stopPropagation() {
    _propagationStopped = true;
    _stopPropagationFn?.call();
  }

  /// Whether [preventDefault] has been called.
  bool get defaultPrevented => _defaultPrevented;

  /// Whether [stopPropagation] has been called.
  bool get propagationStopped => _propagationStopped;

  /// Test helper — creates a fake click event.
  factory BloomEvent.fakeClick() => BloomEvent(type: 'click');

  /// Test helper — creates a fake input event with [value].
  factory BloomEvent.fakeInput(String value) =>
      BloomEvent(type: 'input', value: value);

  /// Test helper — creates a fake change event.
  factory BloomEvent.fakeChange({String? value, bool? checked}) =>
      BloomEvent(type: 'change', value: value, checked: checked);

  /// Test helper — creates any fake event.
  factory BloomEvent.fake(String type, {String? value}) =>
      BloomEvent(type: type, value: value);

  /// Test helper — creates a fake keydown event.
  factory BloomEvent.fakeKeyDown(String key, {String? code}) =>
      BloomEvent(type: 'keydown', key: key, code: code ?? key);

  /// Test helper — creates a fake mousemove event.
  factory BloomEvent.fakeMouseMove(double x, double y) =>
      BloomEvent(type: 'mousemove', clientX: x, clientY: y);
}

/// Handler signature for Bloom events.
typedef BloomEventHandler = void Function(BloomEvent event);
