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

  final void Function()? _preventDefaultFn;
  final void Function()? _stopPropagationFn;

  bool _defaultPrevented = false;
  bool _propagationStopped = false;

  BloomEvent({
    required this.type,
    this.value,
    this.checked,
    this.rawTarget,
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
}

/// Handler signature for Bloom events.
typedef BloomEventHandler = void Function(BloomEvent event);
