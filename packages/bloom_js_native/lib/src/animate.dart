// lib/src/animate.dart
import 'framework.dart';

/// A single keyframe stop in a CSS animation at a normalized offset (0.0 to 1.0).
///
/// Defines the CSS declarations applied at a specific percentage point in the animation timeline.
/// An [offset] of 0.0 corresponds to `0%` (`from`) and 1.0 corresponds to `100%` (`to`).
///
/// ```dart
/// const stop = BloomKeyframe(
///   offset: 0.5,
///   styles: {'opacity': '0.5', 'transform': 'scale(1.1)'},
/// );
/// ```
class BloomKeyframe {
  /// Normalized position in the animation cycle (0.0 = `0%`, 1.0 = `100%`).
  final double offset;

  /// Map of CSS property names to values active at this keyframe (e.g. `{'opacity': '0'}`).
  final Map<String, String> styles;

  /// Creates a keyframe stop at [offset] with the specified [styles].
  const BloomKeyframe({required this.offset, required this.styles});

  /// Returns the CSS percentage string representation (e.g. `'50%'` for offset `0.5`).
  String toCssPercent() => '${(offset * 100).round()}%';

  /// Returns the formatted keyframe CSS block (e.g. `'0%{opacity:0;transform:scale(0.8)}'`).
  String toCssBlock() {
    final decls = styles.entries.map((e) => '${e.key}:${e.value}').join(';');
    return '${toCssPercent()}{$decls}';
  }
}

/// Immutable CSS animation descriptor defining `@keyframes` rules and timing properties.
///
/// Generates CSS keyframe definitions and the shorthand inline `animation` style string.
///
/// ### Backend Behavior
/// - **Browser (`mount.dart`)**: When an [Animated] node is mounted, the `@keyframes` block
///   is created as a `<style>` element and appended to `document.head`. Injection is
///   deduplicated by [name] for the lifetime of the page.
/// - **SSR (`html.dart`)**: Emits a `<style>` block containing the `@keyframes` definition
///   on first occurrence (deduplicated by [name] per render pass) and wraps the child in a
///   `<div>` carrying the computed `animation` inline style.
///
/// ```dart
/// const pulse = BloomAnimation(
///   name: 'custom-pulse',
///   duration: Duration(milliseconds: 500),
///   iterations: -1, // infinite
///   easing: 'ease-in-out',
///   keyframes: [
///     BloomKeyframe(offset: 0.0, styles: {'transform': 'scale(1)'}),
///     BloomKeyframe(offset: 0.5, styles: {'transform': 'scale(1.08)'}),
///     BloomKeyframe(offset: 1.0, styles: {'transform': 'scale(1)'}),
///   ],
/// );
/// ```
class BloomAnimation {
  /// The CSS animation identifier used in `@keyframes` and the `animation` shorthand property.
  final String name;

  /// Ordered list of [BloomKeyframe] stops.
  final List<BloomKeyframe> keyframes;

  /// Total duration of one animation cycle. Defaults to 300 milliseconds.
  final Duration duration;

  /// Delay before the animation commences. Defaults to [Duration.zero].
  final Duration delay;

  /// Number of iterations to play. Use `-1` for infinite repeating (`infinite`). Defaults to `1`.
  final int iterations;

  /// CSS easing timing function (e.g. `'ease'`, `'linear'`, `'cubic-bezier(...)'`). Defaults to `'ease'`.
  final String easing;

  /// CSS `animation-fill-mode` (e.g. `'both'`, `'forwards'`, `'backwards'`). Defaults to `'both'`.
  final String fillMode;

  /// CSS `animation-direction` (e.g. `'normal'`, `'reverse'`, `'alternate'`). Defaults to `'normal'`.
  final String direction;

  /// Creates a new immutable [BloomAnimation] descriptor.
  const BloomAnimation({
    required this.name,
    required this.keyframes,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.iterations = 1,
    this.easing = 'ease',
    this.fillMode = 'both',
    this.direction = 'normal',
  });

  /// Returns the complete `@keyframes <name> { ... }` CSS block.
  String toKeyframesCSS() {
    final stops = keyframes.map((k) => k.toCssBlock()).join('');
    return '@keyframes $name{$stops}';
  }

  /// Returns the CSS `animation` shorthand value formatted for an inline `style` attribute.
  String toInlineStyle() {
    final iterStr = iterations == -1 ? 'infinite' : '$iterations';
    return 'animation:$name ${duration.inMilliseconds}ms $easing ${delay.inMilliseconds}ms $iterStr $direction $fillMode';
  }
}

/// DSL widget that wraps [child] with the CSS keyframe animation described by [animation].
///
/// A `const`-friendly alias for [AnimatedNode]. Injects the `@keyframes` definition into
/// `document.head` (browser) or the SSR stream and encloses [child] in a `<div>` with
/// the calculated `animation` inline style.
///
/// ```dart
/// Animated(
///   animation: BloomAnimationPresets.fadeIn,
///   child: const Div(
///     className: 'notification-toast',
///     text: 'Changes saved successfully',
///   ),
/// )
/// ```
class Animated extends AnimatedNode {
  /// Creates an [Animated] wrapper node applying [animation] to [child].
  const Animated({required super.animation, required super.child});
}

/// Ready-to-use [BloomAnimation] presets for common UI transitions.
///
/// Access preset instances via [BloomAnimationPresets.fadeIn], [BloomAnimationPresets.scaleIn], etc.
class BloomAnimationPresets {
  BloomAnimationPresets._();

  /// Fades element opacity from `0` to `1` over 300 milliseconds.
  static const fadeIn = BloomAnimation(
    name: 'bloom-fade-in',
    keyframes: [
      BloomKeyframe(offset: 0.0, styles: {'opacity': '0'}),
      BloomKeyframe(offset: 1.0, styles: {'opacity': '1'}),
    ],
  );

  /// Fades element opacity from `1` to `0` over 300 milliseconds.
  static const fadeOut = BloomAnimation(
    name: 'bloom-fade-out',
    keyframes: [
      BloomKeyframe(offset: 0.0, styles: {'opacity': '1'}),
      BloomKeyframe(offset: 1.0, styles: {'opacity': '0'}),
    ],
  );

  /// Translates element horizontally from `-100%` to `0` with a concurrent fade in.
  static const slideInLeft = BloomAnimation(
    name: 'bloom-slide-in-left',
    keyframes: [
      BloomKeyframe(
          offset: 0.0,
          styles: {'transform': 'translateX(-100%)', 'opacity': '0'}),
      BloomKeyframe(
          offset: 1.0,
          styles: {'transform': 'translateX(0)', 'opacity': '1'}),
    ],
  );

  /// Translates element horizontally from `100%` to `0` with a concurrent fade in.
  static const slideInRight = BloomAnimation(
    name: 'bloom-slide-in-right',
    keyframes: [
      BloomKeyframe(
          offset: 0.0,
          styles: {'transform': 'translateX(100%)', 'opacity': '0'}),
      BloomKeyframe(
          offset: 1.0,
          styles: {'transform': 'translateX(0)', 'opacity': '1'}),
    ],
  );

  /// Scales element from `0.8` to `1.0` with a concurrent fade in.
  static const scaleIn = BloomAnimation(
    name: 'bloom-scale-in',
    keyframes: [
      BloomKeyframe(
          offset: 0.0, styles: {'transform': 'scale(0.8)', 'opacity': '0'}),
      BloomKeyframe(
          offset: 1.0, styles: {'transform': 'scale(1)', 'opacity': '1'}),
    ],
  );

  /// Continuously pulses element scale between `1.0` and `1.05` in an infinite loop.
  static const pulse = BloomAnimation(
    name: 'bloom-pulse',
    keyframes: [
      BloomKeyframe(offset: 0.0, styles: {'transform': 'scale(1)'}),
      BloomKeyframe(offset: 0.5, styles: {'transform': 'scale(1.05)'}),
      BloomKeyframe(offset: 1.0, styles: {'transform': 'scale(1)'}),
    ],
    iterations: -1,
    easing: 'ease-in-out',
  );
}

