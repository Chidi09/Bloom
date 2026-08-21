import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'style_resolver.dart';

/// MultiChildRenderObjectWidget implementing standard CSS Flexbox for native mobile.
class BloomFlexLayout extends MultiChildRenderObjectWidget {
  final BloomComputedStyle style;

  const BloomFlexLayout({
    super.key,
    required this.style,
    super.children,
  });

  @override
  RenderBloomFlex createRenderObject(BuildContext context) {
    return RenderBloomFlex(style: style);
  }

  @override
  void updateRenderObject(BuildContext context, RenderBloomFlex renderObject) {
    renderObject.style = style;
  }
}

class BloomFlexParentData extends ContainerBoxParentData<RenderBox> {
  int flexGrow = 0;
  int flexShrink = 1;
}

class RenderBloomFlex extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, BloomFlexParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, BloomFlexParentData> {
  BloomComputedStyle _style;

  RenderBloomFlex({required BloomComputedStyle style}) : _style = style;

  BloomComputedStyle get style => _style;
  set style(BloomComputedStyle value) {
    if (_style != value) {
      _style = value;
      markNeedsLayout();
      markNeedsPaint();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BloomFlexParentData) {
      child.parentData = BloomFlexParentData();
    }
  }

  @override
  void performLayout() {
    final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
    final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : double.infinity;

    final targetW = style.width ??
        (style.percentWidth != null && maxW.isFinite ? maxW * style.percentWidth! : null);
    final targetH = style.height ??
        (style.percentHeight != null && maxH.isFinite ? maxH * style.percentHeight! : null);

    final innerW = targetW ?? (maxW.isFinite ? maxW : 0.0);
    final isVertical = style.flexDirection == Axis.vertical;
    final gap = style.gap;

    double currentMain = 0.0;
    double maxCrossInLine = 0.0;

    RenderBox? child = firstChild;
    final childrenList = <RenderBox>[];
    while (child != null) {
      final childParentData = child.parentData! as BloomFlexParentData;
      childrenList.add(child);
      child = childParentData.nextSibling;
    }

    if (childrenList.isEmpty) {
      size = constraints.constrain(Size(
        targetW ?? 0.0,
        targetH ?? 0.0,
      ));
      return;
    }

    // Measure children
    final childSizes = <Size>[];
    for (final c in childrenList) {
      c.layout(
        BoxConstraints(
          maxWidth: isVertical ? (innerW.isFinite && innerW > 0 ? innerW : maxW) : maxW,
          maxHeight: isVertical ? maxH : (targetH ?? maxH),
        ),
        parentUsesSize: true,
      );
      childSizes.add(c.size);
    }

    // Position children along main axis
    for (var i = 0; i < childrenList.length; i++) {
      final c = childrenList[i];
      final cSize = childSizes[i];
      final childParentData = c.parentData! as BloomFlexParentData;

      if (isVertical) {
        childParentData.offset = Offset(0, currentMain);
        currentMain += cSize.height + (i < childrenList.length - 1 ? gap : 0.0);
        maxCrossInLine = math.max(maxCrossInLine, cSize.width);
      } else {
        childParentData.offset = Offset(currentMain, 0);
        currentMain += cSize.width + (i < childrenList.length - 1 ? gap : 0.0);
        maxCrossInLine = math.max(maxCrossInLine, cSize.height);
      }
    }

    final totalWidth = isVertical ? (targetW ?? maxCrossInLine) : (targetW ?? currentMain);
    final totalHeight = isVertical ? (targetH ?? currentMain) : (targetH ?? maxCrossInLine);

    size = constraints.constrain(Size(totalWidth, totalHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
