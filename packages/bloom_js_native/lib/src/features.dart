// lib/src/features.dart
import 'dart:collection';

import 'package:signals_core/signals_core.dart';

/// Dynamic, signal-backed feature flags engine for runtime gating and progressive rollout.
///
/// [BloomFeatureFlags] allows defining, evaluating, and observing boolean feature flags.
/// Each registered flag is backed by a reactive [Signal], meaning components observing a flag
/// via [watch] or `Show` automatically re-render when the flag value is toggled or overridden.
///
/// ### Flag Evaluation & Precedence
/// 1. If an explicit override or runtime state has been assigned via [setOverride], [register],
///    or [registerAll], the current signal value is used.
/// 2. If the requested flag has never been registered or watched, the query method falls back
///    to the supplied `defaultValue`.
/// 3. Calling [clearOverrides] resets all active signals back to their registered default values.
///
/// ### Backend Behavior
/// - **Browser (`mount`)**: Subscribed `Live` and `Show` descriptors react dynamically when
///   flags change via [setOverride] or [registerAll].
/// - **SSR (`renderToHtml`)**: Flag evaluations via [isEnabled] or [watch] run synchronously
///   during HTML generation. SSR renders the branch according to the flag's initial state.
///
/// ### Example
/// ```dart
/// final features = BloomFeatureFlags();
///
/// // Register feature flags with default values
/// features.registerAll({
///   'new_dashboard': true,
///   'beta_export': false,
/// });
///
/// // Conditionally render in UI
/// BloomNode buildHeader() {
///   return Div(
///     children: [
///       Show(
///         () => features.watch('beta_export').value,
///         child: Button(text: 'Export (Beta)'),
///       ),
///     ],
///   );
/// }
///
/// // Dynamically toggle at runtime (e.g. from an admin panel or remote config)
/// features.setOverride('beta_export', true);
/// ```
class BloomFeatureFlags {
  final Map<String, Signal<bool>> _flags = {};
  final Map<String, bool> _defaults = {};

  /// Creates a new, isolated [BloomFeatureFlags] engine.
  ///
  /// Typically registered as a singleton in [BloomContainer] or stored globally.
  ///
  /// ```dart
  /// provideSingleton(() => BloomFeatureFlags());
  /// ```
  BloomFeatureFlags();

  /// Synchronously checks whether [flagName] is currently enabled.
  ///
  /// Returns the current value of the flag if registered or previously observed.
  /// If the flag is unregistered and has never been watched, returns [defaultValue] (defaults to `false`).
  /// This is a one-shot read and does NOT subscribe to reactive signal updates unless
  /// called inside an active signal tracking context.
  ///
  /// ```dart
  /// if (features.isEnabled('dark_mode_v2')) {
  ///   enableDarkModeV2();
  /// }
  /// ```
  bool isEnabled(String flagName, {bool defaultValue = false}) {
    if (_flags.containsKey(flagName)) {
      return _flags[flagName]!.value;
    }
    return defaultValue;
  }

  /// Returns a reactive [ReadonlySignal] tracking the boolean state of [flagName].
  ///
  /// If the flag does not already exist, it is lazily created and initialized with [defaultValue].
  /// Reading `.value` inside a `Live`, `Show`, or `effect` establishes a reactive dependency,
  /// causing the observing block to re-execute whenever the flag changes.
  ///
  /// ```dart
  /// final betaSignal = features.watch('beta_chat');
  ///
  /// Live(() => betaSignal.value ? ChatWidget() : DisabledWidget())
  /// ```
  ReadonlySignal<bool> watch(String flagName, {bool defaultValue = false}) {
    return _getOrCreateSignal(flagName, defaultValue: defaultValue);
  }

  /// Sets or overrides the runtime boolean state of [flagName].
  ///
  /// Updates the underlying [Signal] immediately. If the flag has not yet been registered,
  /// it is created with [value] as its current state. All reactive observers watching
  /// this flag are notified synchronously.
  ///
  /// ```dart
  /// features.setOverride('experimental_feature', true);
  /// ```
  void setOverride(String flagName, bool value) {
    final sig = _getOrCreateSignal(flagName, defaultValue: value);
    sig.value = value;
  }

  /// Registers a feature flag with its default boolean state.
  ///
  /// Stores [defaultValue] as the baseline fallback for [clearOverrides].
  /// If the flag signal already exists, its value is preserved; otherwise, a new signal
  /// initialized to [defaultValue] is allocated.
  ///
  /// ```dart
  /// features.register('analytics_tracking', defaultValue: true);
  /// ```
  void register(String flagName, {bool defaultValue = false}) {
    _defaults[flagName] = defaultValue;
    if (!_flags.containsKey(flagName)) {
      _flags[flagName] = signal(defaultValue);
    }
  }

  /// Registers multiple feature flags simultaneously from a map.
  ///
  /// Values can be boolean (`true`/`false`) or strings (`"true"`, `"false"`).
  /// Updates existing flags' values and records the new defaults. Useful for initializing
  /// flags from JSON payloads, server-rendered configuration, or remote config endpoints.
  ///
  /// ```dart
  /// features.registerAll({
  ///   'checkout_v2': true,
  ///   'promo_banner': 'true',
  ///   'ai_suggestions': false,
  /// });
  /// ```
  void registerAll(Map<String, dynamic> flags) {
    flags.forEach((key, val) {
      final boolVal =
          val is bool ? val : val.toString().toLowerCase() == 'true';
      _defaults[key] = boolVal;
      if (_flags.containsKey(key)) {
        _flags[key]!.value = boolVal;
      } else {
        _flags[key] = signal(boolVal);
      }
    });
  }

  /// Restores all registered feature flags to their original default values.
  ///
  /// Reverts any temporary overrides applied via [setOverride]. Unregistered flags
  /// that have no default recorded will revert to `false`.
  ///
  /// ```dart
  /// features.clearOverrides();
  /// ```
  void clearOverrides() {
    _flags.forEach((key, sig) {
      sig.value = _defaults[key] ?? false;
    });
  }

  /// Resets the engine by removing all flags, signals, and defaults.
  ///
  /// Primarily intended for test teardown to ensure test isolation between cases.
  ///
  /// ```dart
  /// features.reset();
  /// ```
  void reset() {
    _flags.clear();
    _defaults.clear();
  }

  /// Returns an immutable snapshot map of all registered flag names and their current boolean states.
  ///
  /// ```dart
  /// final snapshot = features.getAll();
  /// print('Active flags: $snapshot');
  /// ```
  Map<String, bool> getAll() {
    final map = <String, bool>{};
    _flags.forEach((k, v) => map[k] = v.value);
    return UnmodifiableMapView(map);
  }

  Signal<bool> _getOrCreateSignal(String name, {required bool defaultValue}) {
    if (!_flags.containsKey(name)) {
      _flags[name] = signal(defaultValue);
      _defaults.putIfAbsent(name, () => defaultValue);
    }
    return _flags[name]!;
  }
}
