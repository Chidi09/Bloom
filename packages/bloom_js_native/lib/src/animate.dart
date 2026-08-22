// lib/src/animate.dart
import 'framework.dart';

/// A single keyframe stop in a CSS animation (offset 0.0–1.0).
class BloomKeyframe {
  /// Normalized position: 0.0 = from, 1.0 = to.
  final double offset;

  /// CSS property/value pairs at this keyframe (e.g. `{'opacity': '0'}`).
  final Map<String, String> styles;

  const BloomKeyframe({required this.offset, required this.styles});

  /// Returns the CSS percentage string (e.g. `'50%'` for offset 0.5).
  String toCssPercent() => '${(offset * 100).round()}%';

  /// Returns the full keyframe CSS block (e.g. `'0%{opacity:0}'`).
  String toCssBlock() {
    final decls = styles.entries.map((e) => '${e.key}:${e.value}').join(';');
    return '${toCssPercent()}{$decls}';
  }
}

/// Immutable CSS animation descriptor — generates `@keyframes` and inline `animation` style.
class BloomAnimation {
  /// The animation identifier used in both `@keyframes` and the `animation` property.
  final String name;

  /// Ordered keyframe stops.
  final List<BloomKeyframe> keyframes;

  /// Total cycle duration. Defaults to 300ms.
  final Duration duration;

  /// Start delay. Defaults to zero.
  final Duration delay;

  /// Number of iterations. Use `-1` for infinite. Defaults to 1.
  final int iterations;

  /// CSS easing function. Defaults to `'ease'`.
  final String easing;

  /// CSS `animation-fill-mode`. Defaults to `'both'`.
  final String fillMode;

  /// CSS `animation-direction`. Defaults to `'normal'`.
  final String direction;

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

  /// Returns the complete `@keyframes name { ... }` CSS block.
  String toKeyframesCSS() {
    final stops = keyframes.map((k) => k.toCssBlock()).join('');
    return '@keyframes $name{$stops}';
  }

  /// Returns the CSS `animation` shorthand value suitable for an inline `style` attribute.
  String toInlineStyle() {
    final iterStr = iterations == -1 ? 'infinite' : '$iterations';
    return 'animation:$name ${duration.inMilliseconds}ms $easing ${delay.inMilliseconds}ms $iterStr $direction $fillMode';
  }
}

/// `const`-safe DSL alias for [AnimatedNode] (declared in `framework.dart`
/// because `BloomNode` is a sealed class and direct subtypes must live in
/// its own library file).
class Animated extends AnimatedNode {
  const Animated({required super.animation, required super.child});
}

/// Ready-to-use animation presets. Use via `BloomAnimationPresets.fadeIn` etc.
class BloomAnimationPresets {
  BloomAnimationPresets._();

  static const fadeIn = BloomAnimation(
    name: 'bloom-fade-in',
    keyframes: [
      BloomKeyframe(offset: 0.0, styles: {'opacity': '0'}),
      BloomKeyframe(offset: 1.0, styles: {'opacity': '1'}),
    ],
  );

  static const fadeOut = BloomAnimation(
    name: 'bloom-fade-out',
    keyframes: [
      BloomKeyframe(offset: 0.0, styles: {'opacity': '1'}),
      BloomKeyframe(offset: 1.0, styles: {'opacity': '0'}),
    ],
  );

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

  static const scaleIn = BloomAnimation(
    name: 'bloom-scale-in',
    keyframes: [
      BloomKeyframe(
          offset: 0.0, styles: {'transform': 'scale(0.8)', 'opacity': '0'}),
      BloomKeyframe(
          offset: 1.0, styles: {'transform': 'scale(1)', 'opacity': '1'}),
    ],
  );

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
