import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:signals/signals.dart';
import 'style_resolver.dart';

/// High-performance LeafRenderObjectWidget that binds directly to a signal function.
class BloomLeafTextWidget extends LeafRenderObjectWidget {
  final String Function() textFn;
  final BloomComputedStyle style;

  const BloomLeafTextWidget({
    super.key,
    required this.textFn,
    required this.style,
  });

  @override
  RenderBloomLeafText createRenderObject(BuildContext context) {
    return RenderBloomLeafText(textFn: textFn, style: style);
  }

  @override
  void updateRenderObject(BuildContext context, RenderBloomLeafText renderObject) {
    renderObject
      ..textFn = textFn
      ..style = style;
  }
}

class RenderBloomLeafText extends RenderBox {
  String Function() _textFn;
  BloomComputedStyle _style;
  EffectCleanup? _cleanup;
  late TextPainter _textPainter;
  String _cachedText = '';

  RenderBloomLeafText({
    required String Function() textFn,
    required BloomComputedStyle style,
  })  : _textFn = textFn,
        _style = style {
    _initTextPainter();
  }

  String Function() get textFn => _textFn;
  set textFn(String Function() value) {
    if (_textFn != value) {
      _textFn = value;
      _subscribe();
    }
  }

  BloomComputedStyle get style => _style;
  set style(BloomComputedStyle value) {
    if (_style != value) {
      _style = value;
      _initTextPainter();
      markNeedsLayout();
      markNeedsPaint();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _subscribe();
  }

  @override
  void detach() {
    _cleanup?.call();
    _cleanup = null;
    super.detach();
  }

  void _subscribe() {
    _cleanup?.call();
    _cleanup = effect(() {
      final newText = _textFn();
      if (_cachedText != newText) {
        _cachedText = newText;
        _textPainter.text = TextSpan(
          text: _cachedText,
          style: TextStyle(
            fontSize: _style.fontSize,
            fontWeight: _style.fontWeight,
            fontFamily: _style.fontFamily,
            color: _style.textColor ?? const Color(0xFFFFFFFF),
            decoration: _style.textDecoration,
          ),
        );
        markNeedsLayout();
        markNeedsPaint();
      }
    });
  }

  void _initTextPainter() {
    _textPainter = TextPainter(
      text: TextSpan(
        text: _cachedText,
        style: TextStyle(
          fontSize: _style.fontSize,
          fontWeight: _style.fontWeight,
          fontFamily: _style.fontFamily,
          color: _style.textColor ?? const Color(0xFFFFFFFF),
          decoration: _style.textDecoration,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
  }

  @override
  void performLayout() {
    _textPainter.layout(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
    );
    size = constraints.constrain(_textPainter.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _textPainter.paint(context.canvas, offset);
  }
}
