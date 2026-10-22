/// Optional Flutter-shaped layout, styling, and animation helpers for Bloom.
///
/// ```dart
/// Row(children: [StyledText('Hello')]);
/// ```
library;

import 'dart:math' as math;

import '../framework.dart';

String _px(num value) => '${value}px';
String _css(Iterable<String> declarations) =>
    declarations.where((value) => value.isNotEmpty).join('; ');

/// An ARGB color convertible to CSS.
///
/// ```dart
/// const color = Color(0xffff0000);
/// ```
class Color {
  /// The packed ARGB value.
  final int value;

  /// Creates a color from a packed ARGB integer.
  const Color(this.value);

  /// Creates a color from separate alpha, red, green, and blue channels.
  const Color.fromARGB(int a, int r, int g, int b)
      : value = ((a & 255) << 24) |
            ((r & 255) << 16) |
            ((g & 255) << 8) |
            (b & 255);

  /// Creates a color from RGB channels and opacity from zero to one.
  Color.fromRGBO(int r, int g, int b, double opacity)
      : value = (((opacity.clamp(0, 1) * 255).round() & 255) << 24) |
            ((r & 255) << 16) |
            ((g & 255) << 8) |
            (b & 255);

  /// CSS hex for opaque colors and `rgba(...)` for translucent colors.
  String get css {
    final a = (value >> 24) & 255;
    final r = (value >> 16) & 255;
    final g = (value >> 8) & 255;
    final b = value & 255;
    if (a == 255) {
      String hex(int channel) => channel.toRadixString(16).padLeft(2, '0');
      return '#${hex(r)}${hex(g)}${hex(b)}';
    }
    return 'rgba($r, $g, $b, ${(a / 255).toStringAsFixed(3)})';
  }
}

/// Common CSS colors.
///
/// ```dart
/// Container(color: Colors.blue);
/// ```
class Colors {
  /// Fully transparent.
  static const transparent = Color(0x00000000);

  /// Black.
  static const black = Color(0xff000000);

  /// White.
  static const white = Color(0xffffffff);

  /// Red.
  static const red = Color(0xfff44336);

  /// Green.
  static const green = Color(0xff4caf50);

  /// Blue.
  static const blue = Color(0xff2196f3);

  /// Grey.
  static const grey = Color(0xff9e9e9e);

  /// Amber.
  static const amber = Color(0xffffc107);

  /// Indigo.
  static const indigo = Color(0xff3f51b5);

  /// Teal.
  static const teal = Color(0xff009688);
}

/// Four-sided padding or margin in logical pixels.
///
/// ```dart
/// Padding(padding: EdgeInsets.all(8), child: StyledText('Hi'));
/// ```
class EdgeInsets {
  /// Left inset.
  final num left;

  /// Top inset.
  final num top;

  /// Right inset.
  final num right;

  /// Bottom inset.
  final num bottom;

  /// Creates insets for each side.
  const EdgeInsets.only(
      {this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});

  /// Applies one inset to every side.
  const EdgeInsets.all(num value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  /// Creates symmetric vertical and horizontal insets.
  const EdgeInsets.symmetric({num vertical = 0, num horizontal = 0})
      : left = horizontal,
        top = vertical,
        right = horizontal,
        bottom = vertical;

  /// Zero inset.
  static const zero = EdgeInsets.all(0);

  /// CSS four-value shorthand.
  String get css => '${_px(top)} ${_px(right)} ${_px(bottom)} ${_px(left)}';
}

/// Rounded corner radius in logical pixels.
///
/// ```dart
/// BoxDecoration(borderRadius: BorderRadius.circular(8));
/// ```
class BorderRadius {
  /// Radius in logical pixels.
  final num radius;

  /// Creates a circular radius.
  const BorderRadius.circular(this.radius);

  /// Creates the same radius for every corner.
  const BorderRadius.all(this.radius);

  /// CSS border-radius value.
  String get css => _px(radius);
}

/// A solid border around a box.
///
/// ```dart
/// BoxDecoration(border: Border.all(color: Colors.grey));
/// ```
class Border {
  /// Border width in logical pixels.
  final num width;

  /// Border color.
  final Color color;

  /// Creates a solid border.
  const Border.all({this.width = 1, this.color = Colors.black});

  /// CSS border declaration.
  String get css => '${_px(width)} solid ${color.css}';
}

/// A CSS box shadow.
///
/// ```dart
/// const shadow = BoxShadow(blurRadius: 8);
/// ```
class BoxShadow {
  /// Shadow color.
  final Color color;

  /// Horizontal offset.
  final num x;

  /// Vertical offset.
  final num y;

  /// Blur radius.
  final num blurRadius;

  /// Spread radius.
  final num spreadRadius;

  /// Creates a shadow with optional offsets and blur.
  const BoxShadow(
      {this.color = Colors.black,
      this.x = 0,
      this.y = 2,
      this.blurRadius = 4,
      this.spreadRadius = 0});

  /// CSS box-shadow value.
  String get css => '${_px(x)} ${_px(y)} ${_px(blurRadius)} '
      '${_px(spreadRadius)} ${color.css}';
}

/// CSS decoration values for a [Container].
///
/// ```dart
/// Container(decoration: BoxDecoration(color: Colors.white));
/// ```
class BoxDecoration {
  /// Optional background color.
  final Color? color;

  /// Optional corner radius.
  final BorderRadius? borderRadius;

  /// Optional border.
  final Border? border;

  /// Box shadows.
  final List<BoxShadow> boxShadow;

  /// Creates a box decoration.
  const BoxDecoration(
      {this.color, this.borderRadius, this.border, this.boxShadow = const []});

  /// CSS declarations for this decoration.
  String get css => _css([
        if (color != null) 'background-color: ${color!.css}',
        if (borderRadius != null) 'border-radius: ${borderRadius!.css}',
        if (border != null) 'border: ${border!.css}',
        if (boxShadow.isNotEmpty)
          'box-shadow: ${boxShadow.map((shadow) => shadow.css).join(', ')}',
      ]);
}

/// Main-axis placement for [Row] and [Column].
///
/// ```dart
/// Row(mainAxisAlignment: MainAxisAlignment.center);
/// ```
enum MainAxisAlignment {
  /// Place children at the start.
  start,

  /// Place children at the end.
  end,

  /// Center children.
  center,

  /// Place equal space between children.
  spaceBetween,

  /// Place equal space around children.
  spaceAround,

  /// Place equal space around and between children.
  spaceEvenly,
}

/// Cross-axis placement for [Row] and [Column].
///
/// ```dart
/// Column(crossAxisAlignment: CrossAxisAlignment.stretch);
/// ```
enum CrossAxisAlignment {
  /// Align children at the start.
  start,

  /// Align children at the end.
  end,

  /// Center children.
  center,

  /// Stretch children across the cross axis.
  stretch,

  /// Align text baselines.
  baseline,
}

/// Whether a flex layout takes minimum or maximum main-axis space.
///
/// ```dart
/// Row(mainAxisSize: MainAxisSize.min);
/// ```
enum MainAxisSize {
  /// Take only the space needed by children.
  min,

  /// Take the available main-axis space.
  max,
}

/// Nine-point box alignment.
///
/// ```dart
/// Align(alignment: Alignment.bottomRight, child: StyledText('Hi'));
/// ```
enum Alignment {
  /// Top-left alignment.
  topLeft,

  /// Top-center alignment.
  topCenter,

  /// Top-right alignment.
  topRight,

  /// Center-left alignment.
  centerLeft,

  /// Center alignment.
  center,

  /// Center-right alignment.
  centerRight,

  /// Bottom-left alignment.
  bottomLeft,

  /// Bottom-center alignment.
  bottomCenter,

  /// Bottom-right alignment.
  bottomRight,
}

String _justify(MainAxisAlignment value) => switch (value) {
      MainAxisAlignment.start => 'flex-start',
      MainAxisAlignment.end => 'flex-end',
      MainAxisAlignment.center => 'center',
      MainAxisAlignment.spaceBetween => 'space-between',
      MainAxisAlignment.spaceAround => 'space-around',
      MainAxisAlignment.spaceEvenly => 'space-evenly',
    };
String _align(CrossAxisAlignment value) => switch (value) {
      CrossAxisAlignment.start => 'flex-start',
      CrossAxisAlignment.end => 'flex-end',
      CrossAxisAlignment.center => 'center',
      CrossAxisAlignment.stretch => 'stretch',
      CrossAxisAlignment.baseline => 'baseline',
    };
String _place(Alignment value) => switch (value) {
      Alignment.topLeft => 'start start',
      Alignment.topCenter => 'start center',
      Alignment.topRight => 'start end',
      Alignment.centerLeft => 'center start',
      Alignment.center => 'center center',
      Alignment.centerRight => 'center end',
      Alignment.bottomLeft => 'end start',
      Alignment.bottomCenter => 'end center',
      Alignment.bottomRight => 'end end',
    };

/// A horizontal flex layout.
///
/// ```dart
/// Row(children: [StyledText('A'), StyledText('B')], gap: 8);
/// ```
class Row extends ElNode {
  /// Creates a horizontal flex layout.
  ///
  /// ```dart
  /// Row(children: [StyledText('A'), StyledText('B')], gap: 8);
  /// ```
  Row(
      {List<BloomNode> children = const [],
      MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
      CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
      MainAxisSize mainAxisSize = MainAxisSize.max,
      num gap = 0,
      bool wrap = false})
      : super('div',
            children: children,
            style: _css([
              'display: flex',
              'flex-direction: row',
              'justify-content: ${_justify(mainAxisAlignment)}',
              'align-items: ${_align(crossAxisAlignment)}',
              'gap: ${_px(gap)}',
              'flex-wrap: ${wrap ? 'wrap' : 'nowrap'}',
              if (mainAxisSize == MainAxisSize.min) 'width: fit-content',
            ]));
}

/// A vertical flex layout.
///
/// ```dart
/// Column(children: [StyledText('A'), StyledText('B')]);
/// ```
class Column extends ElNode {
  /// Creates a vertical flex layout.
  ///
  /// ```dart
  /// Column(children: [StyledText('A'), StyledText('B')]);
  /// ```
  Column(
      {List<BloomNode> children = const [],
      MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
      CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
      MainAxisSize mainAxisSize = MainAxisSize.max,
      num gap = 0,
      bool wrap = false})
      : super('div',
            children: children,
            style: _css([
              'display: flex',
              'flex-direction: column',
              'justify-content: ${_justify(mainAxisAlignment)}',
              'align-items: ${_align(crossAxisAlignment)}',
              'gap: ${_px(gap)}',
              'flex-wrap: ${wrap ? 'wrap' : 'nowrap'}',
              if (mainAxisSize == MainAxisSize.min) 'height: fit-content',
            ]));
}

/// A relative positioning layout.
///
/// ```dart
/// Stack(children: [Positioned(left: 0, top: 0, child: StyledText('Hi'))]);
/// ```
class Stack extends ElNode {
  /// Creates a relative positioning layout.
  ///
  /// ```dart
  /// Stack(children: [Positioned(left: 0, top: 0, child: StyledText('Hi'))]);
  /// ```
  Stack(
      {List<BloomNode> children = const [],
      Alignment alignment = Alignment.topLeft})
      : super('div',
            children: children,
            style:
                'position: relative; display: grid; place-items: ${_place(alignment)}');
}

/// Absolutely positions a child within a [Stack].
///
/// ```dart
/// Positioned(left: 4, top: 4, child: StyledText('Badge'));
/// ```
class Positioned extends ElNode {
  /// Creates an absolutely positioned child within a [Stack].
  ///
  /// ```dart
  /// Positioned(left: 4, top: 4, child: StyledText('Badge'));
  /// ```
  Positioned(
      {num? left,
      num? top,
      num? right,
      num? bottom,
      num? width,
      num? height,
      required BloomNode child})
      : super('div',
            children: [child],
            style: _css([
              'position: absolute',
              if (left != null) 'left: ${_px(left)}',
              if (top != null) 'top: ${_px(top)}',
              if (right != null) 'right: ${_px(right)}',
              if (bottom != null) 'bottom: ${_px(bottom)}',
              if (width != null) 'width: ${_px(width)}',
              if (height != null) 'height: ${_px(height)}'
            ]));
}

/// Adds padding around a child.
///
/// ```dart
/// Padding(padding: EdgeInsets.all(8), child: StyledText('Hi'));
/// ```
class Padding extends ElNode {
  /// Creates a padded child.
  ///
  /// ```dart
  /// Padding(padding: EdgeInsets.all(8), child: StyledText('Hi'));
  /// ```
  Padding({required EdgeInsets padding, required BloomNode child})
      : super('div', children: [child], style: 'padding: ${padding.css}');
}

/// Centers a child on both axes.
///
/// ```dart
/// Center(child: StyledText('Centered'));
/// ```
class Center extends ElNode {
  /// Creates a child centered on both axes.
  ///
  /// ```dart
  /// Center(child: StyledText('Centered'));
  /// ```
  Center({required BloomNode child})
      : super('div',
            children: [child],
            style: 'display: grid; place-items: center center');
}

/// Aligns a child within available space.
///
/// ```dart
/// Align(alignment: Alignment.topRight, child: StyledText('Hi'));
/// ```
class Align extends ElNode {
  /// Creates an aligned child.
  ///
  /// ```dart
  /// Align(alignment: Alignment.topRight, child: StyledText('Hi'));
  /// ```
  Align({required Alignment alignment, required BloomNode child})
      : super('div',
            children: [child],
            style: 'display: grid; place-items: ${_place(alignment)}');
}

/// Sets explicit dimensions around an optional child.
///
/// ```dart
/// SizedBox(width: 120, child: StyledText('Wide'));
/// ```
class SizedBox extends ElNode {
  /// Creates a box with optional explicit dimensions.
  ///
  /// ```dart
  /// SizedBox(width: 120, child: StyledText('Wide'));
  /// ```
  SizedBox({num? width, num? height, BloomNode? child})
      : super('div',
            children: child == null ? const [] : [child],
            style: _css([
              if (width != null) 'width: ${_px(width)}',
              if (height != null) 'height: ${_px(height)}',
            ]));

  /// Creates a box that fills its parent.
  ///
  /// ```dart
  /// SizedBox.expand(child: StyledText('Fill'));
  /// ```
  SizedBox.expand({BloomNode? child})
      : super('div',
            children: child == null ? const [] : [child],
            style: 'width: 100%; height: 100%');

  /// Creates an empty zero-size box.
  ///
  /// ```dart
  /// SizedBox.shrink();
  /// ```
  SizedBox.shrink() : super('div', style: 'width: 0; height: 0');
}

/// A box with dimensions, spacing, alignment, and decoration.
///
/// ```dart
/// Container(color: Colors.blue, padding: EdgeInsets.all(8), child: StyledText('Hi'));
/// ```
class Container extends ElNode {
  /// Creates a box with dimensions, spacing, alignment, and decoration.
  ///
  /// ```dart
  /// Container(color: Colors.blue, child: StyledText('Hi'));
  /// ```
  Container(
      {BloomNode? child,
      EdgeInsets? padding,
      EdgeInsets? margin,
      Color? color,
      num? width,
      num? height,
      Alignment? alignment,
      BoxDecoration? decoration,
      num? minWidth,
      num? maxWidth,
      num? minHeight,
      num? maxHeight})
      : super('div',
            children: child == null ? const [] : [child],
            style: _css([
              if (padding != null) 'padding: ${padding.css}',
              if (margin != null) 'margin: ${margin.css}',
              if (color != null) 'background-color: ${color.css}',
              if (width != null) 'width: ${_px(width)}',
              if (height != null) 'height: ${_px(height)}',
              if (alignment != null)
                'display: grid; place-items: ${_place(alignment)}',
              if (minWidth != null) 'min-width: ${_px(minWidth)}',
              if (maxWidth != null) 'max-width: ${_px(maxWidth)}',
              if (minHeight != null) 'min-height: ${_px(minHeight)}',
              if (maxHeight != null) 'max-height: ${_px(maxHeight)}',
              decoration?.css ?? '',
            ]));
}

/// Flexible expansion for a flex parent.
///
/// ```dart
/// Expanded(child: StyledText('Fill'));
/// ```
class Expanded extends ElNode {
  /// Creates a child that expands in a flex parent.
  ///
  /// ```dart
  /// Expanded(child: StyledText('Fill'));
  /// ```
  Expanded({int flex = 1, required BloomNode child})
      : super('div', children: [child], style: 'flex: $flex');
}

/// Flexible sizing for a flex parent.
///
/// ```dart
/// Flexible(child: StyledText('Fit'));
/// ```
class Flexible extends ElNode {
  /// Creates a flexibly sized child.
  ///
  /// ```dart
  /// Flexible(child: StyledText('Fit'));
  /// ```
  Flexible({int flex = 1, required BloomNode child})
      : super('div', children: [child], style: 'flex: $flex 1 0%');
}

/// Flexible empty space in a flex parent.
///
/// ```dart
/// Spacer();
/// ```
class Spacer extends ElNode {
  /// Creates flexible empty space.
  ///
  /// ```dart
  /// Spacer();
  /// ```
  Spacer({int flex = 1}) : super('div', style: 'flex: $flex');
}

/// A wrapping flex layout with row and run spacing.
///
/// ```dart
/// Wrap(children: [StyledText('A'), StyledText('B')], spacing: 8);
/// ```
class Wrap extends ElNode {
  /// Creates a wrapping flex layout.
  ///
  /// ```dart
  /// Wrap(children: [StyledText('A'), StyledText('B')], spacing: 8);
  /// ```
  Wrap(
      {List<BloomNode> children = const [],
      num spacing = 0,
      num runSpacing = 0})
      : super('div',
            children: children,
            style: 'display: flex; flex-wrap: wrap; '
                'column-gap: ${_px(spacing)}; row-gap: ${_px(runSpacing)}');
}

/// The direction a scrollable list lays out its children.
///
/// ```dart
/// ListView(scrollDirection: Axis.horizontal);
/// ```
enum Axis {
  /// Lay children out vertically.
  vertical,

  /// Lay children out horizontally.
  horizontal,
}

/// A scrollable list of children.
///
/// ```dart
/// ListView(children: [StyledText('Item')]);
/// ```
class ListView extends ElNode {
  /// Creates a scrollable list of children.
  ///
  /// ```dart
  /// ListView(children: [StyledText('Item')]);
  /// ```
  ListView(
      {List<BloomNode> children = const [],
      EdgeInsets? padding,
      Axis scrollDirection = Axis.vertical})
      : super('div',
            children: children,
            style: _css([
              'overflow: auto',
              'display: flex',
              'flex-direction: ${scrollDirection == Axis.vertical ? 'column' : 'row'}',
              if (padding != null) 'padding: ${padding.css}'
            ]));
}

/// A clickable child with keyboard activation and button semantics.
///
/// ```dart
/// GestureDetector(onTap: save, child: StyledText('Save'));
/// ```
class GestureDetector extends ElNode {
  /// Creates a clickable child with keyboard activation and button semantics.
  ///
  /// ```dart
  /// GestureDetector(onTap: save, child: StyledText('Save'));
  /// ```
  GestureDetector({required void Function() onTap, required BloomNode child})
      : super('div',
            children: [child],
            attrs: const {'role': 'button', 'tabindex': '0'},
            style: 'cursor: pointer',
            on: {
              'click': (_) => onTap(),
              'keydown': (event) {
                if (event.key == 'Enter' ||
                    event.key == ' ' ||
                    event.code == 'Space') {
                  onTap();
                }
              },
            });
}

/// Horizontal text alignment.
///
/// ```dart
/// StyledText('Centered', textAlign: TextAlign.center);
/// ```
enum TextAlign {
  /// Align left.
  left,

  /// Align right.
  right,

  /// Center the text.
  center,

  /// Justify text across the line.
  justify,

  /// Align to the logical start.
  start,

  /// Align to the logical end.
  end,
}

/// Font weight values supported by CSS.
///
/// ```dart
/// StyledText('Semi bold', style: TextStyle(fontWeight: FontWeight.w600));
/// ```
enum FontWeight {
  /// CSS font weight 100.
  w100,

  /// CSS font weight 200.
  w200,

  /// CSS font weight 300.
  w300,

  /// CSS font weight 400.
  w400,

  /// CSS font weight 500.
  w500,

  /// CSS font weight 600.
  w600,

  /// CSS font weight 700.
  w700,

  /// CSS font weight 800.
  w800,

  /// CSS font weight 900.
  w900,

  /// Bold font weight.
  bold,

  /// Normal font weight.
  normal,
}

/// Text decoration values.
///
/// ```dart
/// TextStyle(decoration: TextDecoration.underline);
/// ```
enum TextDecoration {
  /// No text decoration.
  none,

  /// Underline text.
  underline,

  /// Draw a line through text.
  lineThrough,
}

/// CSS text styles.
///
/// ```dart
/// StyledText('Title', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
/// ```
class TextStyle {
  /// Font size in logical pixels.
  final num? fontSize;

  /// Font weight.
  final FontWeight? fontWeight;

  /// Font style string (for example `italic`).
  final String? fontStyle;

  /// Text color.
  final Color? color;

  /// Letter spacing in logical pixels.
  final num? letterSpacing;

  /// Line-height multiplier.
  final num? height;

  /// Font family.
  final String? fontFamily;

  /// Text decoration.
  final TextDecoration? decoration;

  /// Creates CSS text style values.
  const TextStyle(
      {this.fontSize,
      this.fontWeight,
      this.fontStyle,
      this.color,
      this.letterSpacing,
      this.height,
      this.fontFamily,
      this.decoration});

  /// Returns a copy with selected values replaced.
  TextStyle copyWith(
          {num? fontSize,
          FontWeight? fontWeight,
          String? fontStyle,
          Color? color,
          num? letterSpacing,
          num? height,
          String? fontFamily,
          TextDecoration? decoration}) =>
      TextStyle(
          fontSize: fontSize ?? this.fontSize,
          fontWeight: fontWeight ?? this.fontWeight,
          fontStyle: fontStyle ?? this.fontStyle,
          color: color ?? this.color,
          letterSpacing: letterSpacing ?? this.letterSpacing,
          height: height ?? this.height,
          fontFamily: fontFamily ?? this.fontFamily,
          decoration: decoration ?? this.decoration);

  /// CSS declarations for this style.
  String get css => _css([
        if (fontSize != null) 'font-size: ${_px(fontSize!)}',
        if (fontWeight != null)
          'font-weight: ${switch (fontWeight!) {
            FontWeight.bold => 'bold',
            FontWeight.normal => 'normal',
            _ => fontWeight!.index < 9
                ? '${(fontWeight!.index + 1) * 100}'
                : 'normal',
          }}',
        if (fontStyle != null) 'font-style: $fontStyle',
        if (color != null) 'color: ${color!.css}',
        if (letterSpacing != null) 'letter-spacing: ${_px(letterSpacing!)}',
        if (height != null) 'line-height: $height',
        if (fontFamily != null) 'font-family: $fontFamily',
        if (decoration != null)
          'text-decoration: ${switch (decoration!) {
            TextDecoration.none => 'none',
            TextDecoration.underline => 'underline',
            TextDecoration.lineThrough => 'line-through',
          }}',
      ]);
}

/// Text rendered as a span, optionally styled and line-clamped.
///
/// ```dart
/// StyledText('Hello', style: TextStyle(fontWeight: FontWeight.w600));
/// ```
class StyledText extends ElNode {
  /// Creates styled text rendered as a span.
  ///
  /// ```dart
  /// StyledText('Hello', style: TextStyle(fontWeight: FontWeight.w600));
  /// ```
  StyledText(String data,
      {TextStyle? style, TextAlign? textAlign, int? maxLines})
      : super('span',
            text: data,
            style: _css([
              style?.css ?? '',
              if (textAlign != null) 'text-align: ${textAlign.name}',
              if (maxLines != null) 'display: -webkit-box',
              if (maxLines != null) '-webkit-line-clamp: $maxLines',
              if (maxLines != null) '-webkit-box-orient: vertical',
              if (maxLines != null) 'overflow: hidden',
            ]));
}

/// Theme values shared by descendants through CSS custom properties.
///
/// ```dart
/// Theme(data: ThemeData(), child: StyledText('Themed'));
/// ```
class ThemeData {
  /// Primary color.
  final Color primaryColor;

  /// Page background.
  final Color backgroundColor;

  /// Surface color.
  final Color surfaceColor;

  /// Main text color.
  final Color textColor;

  /// Muted text color.
  final Color mutedTextColor;

  /// Corner radius in logical pixels.
  final num borderRadius;

  /// Font family.
  final String fontFamily;

  /// Creates theme values.
  const ThemeData(
      {this.primaryColor = Colors.blue,
      this.backgroundColor = Colors.white,
      this.surfaceColor = Colors.white,
      this.textColor = Colors.black,
      this.mutedTextColor = Colors.grey,
      this.borderRadius = 8,
      this.fontFamily = 'sans-serif'});
}

/// A wrapper that exposes theme values as CSS custom properties.
///
/// ```dart
/// Theme(data: ThemeData(), child: StyledText('Hello'));
/// ```
class Theme extends ElNode {
  /// Creates a wrapper that exposes theme values as CSS custom properties.
  ///
  /// ```dart
  /// Theme(data: ThemeData(), child: StyledText('Hello'));
  /// ```
  Theme({required ThemeData data, required BloomNode child})
      : super('div',
            children: [child],
            style: '--bloom-primary: ${data.primaryColor.css}; '
                '--bloom-background: ${data.backgroundColor.css}; '
                '--bloom-surface: ${data.surfaceColor.css}; --bloom-text: ${data.textColor.css}; '
                '--bloom-muted: ${data.mutedTextColor.css}; --bloom-radius: ${_px(data.borderRadius)}; '
                '--bloom-font: ${data.fontFamily}; font-family: ${data.fontFamily}; '
                'color: ${ThemeColors.text}; background-color: ${ThemeColors.background}');
}

/// CSS references to the nearest [Theme] custom properties.
///
/// ```dart
/// final cssColor = ThemeColors.primary;
/// ```
class ThemeColors {
  /// The primary theme color.
  static const primary = 'var(--bloom-primary)';

  /// The background theme color.
  static const background = 'var(--bloom-background)';

  /// The surface theme color.
  static const surface = 'var(--bloom-surface)';

  /// The text theme color.
  static const text = 'var(--bloom-text)';

  /// The muted theme color.
  static const muted = 'var(--bloom-muted)';

  /// The theme border radius.
  static const radius = 'var(--bloom-radius)';

  /// The theme font family.
  static const font = 'var(--bloom-font)';
}

/// A CSS transition timing function.
///
/// ```dart
/// const curve = Curve('ease-in-out');
/// ```
class Curve {
  /// CSS timing function value.
  final String css;

  /// Creates a CSS timing function.
  const Curve(this.css);

  /// Returns the CSS timing function.
  @override
  String toString() => css;
}

/// CSS transition timing functions.
///
/// ```dart
/// AnimatedOpacity(opacity: () => 0.5, curve: Curves.easeInOut,
///   child: StyledText('Fade'));
/// ```
class Curves {
  /// Linear timing function.
  static const linear = Curve('linear');

  /// Ease timing function.
  static const ease = Curve('ease');

  /// Ease-in timing function.
  static const easeIn = Curve('ease-in');

  /// Ease-out timing function.
  static const easeOut = Curve('ease-out');

  /// Ease-in-out timing function.
  static const easeInOut = Curve('ease-in-out');
}

String _duration(Duration value) => '${math.max(0, value.inMilliseconds)}ms';

/// Reactively transitions an element's opacity.
///
/// ```dart
/// AnimatedOpacity(opacity: () => 1, child: StyledText('Shown'));
/// ```
class AnimatedOpacity extends ElNode {
  /// Creates an element that reactively transitions opacity.
  ///
  /// ```dart
  /// AnimatedOpacity(opacity: () => 1, child: StyledText('Shown'));
  /// ```
  AnimatedOpacity(
      {required double Function() opacity,
      Duration duration = const Duration(milliseconds: 200),
      Curve curve = Curves.easeInOut,
      required BloomNode child})
      : super('div',
            children: [child],
            style: 'transition: opacity ${_duration(duration)} $curve',
            reactiveStyle: () => 'opacity: ${opacity()}');
}

/// Reactively transitions container size, color, padding, and decoration.
///
/// ```dart
/// AnimatedContainer(width: () => 120, child: StyledText('Grow'));
/// ```
class AnimatedContainer extends ElNode {
  /// Creates a container that reactively transitions its styles.
  ///
  /// ```dart
  /// AnimatedContainer(width: () => 120, child: StyledText('Grow'));
  /// ```
  AnimatedContainer(
      {Duration duration = const Duration(milliseconds: 200),
      Curve curve = Curves.easeInOut,
      num? Function()? width,
      num? Function()? height,
      Color? Function()? color,
      EdgeInsets? Function()? padding,
      BoxDecoration? Function()? decoration,
      required BloomNode child})
      : super('div',
            children: [child],
            style: 'transition: all ${_duration(duration)} $curve',
            reactiveStyle: () => _css([
                  if (width?.call() case final value?) 'width: ${_px(value)}',
                  if (height?.call() case final value?) 'height: ${_px(value)}',
                  if (color?.call() case final value?)
                    'background-color: ${value.css}',
                  if (padding?.call() case final value?)
                    'padding: ${value.css}',
                  decoration?.call()?.css ?? '',
                ]));
}
