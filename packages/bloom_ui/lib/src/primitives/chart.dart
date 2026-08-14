// lib/src/primitives/chart.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/bloom_color_scheme.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomChartConfig {
  final String label;
  final Color? color;

  const BloomChartConfig({required this.label, this.color});
}

enum BloomChartType { area, bar, line, pie, radar, radial }

class BloomChartData {
  final List<String> labels;
  final List<BloomChartSeries> series;

  const BloomChartData({required this.labels, required this.series});
}

class BloomChartSeries {
  final String name;
  final List<num> values;
  final Color? color;

  const BloomChartSeries({required this.name, required this.values, this.color});
}

enum BloomLegendPosition { bottom, top }

/// Token-driven, dependency-free chart supporting area/bar/line/pie/radar/radial.
class BloomChart extends StatefulWidget {
  final BloomChartData data;
  final BloomChartType type;
  final double? height;
  final bool showLegend;
  final bool showTooltip;
  final bool showGrid;
  final bool showXAxis;
  final bool showYAxis;
  final BloomLegendPosition legendPosition;
  final Map<String, BloomChartConfig>? config;
  final int radiusInPixels;

  const BloomChart({
    super.key,
    required this.data,
    this.type = BloomChartType.bar,
    this.height,
    this.showLegend = true,
    this.showTooltip = true,
    this.showGrid = true,
    this.showXAxis = true,
    this.showYAxis = true,
    this.legendPosition = BloomLegendPosition.bottom,
    this.config,
    this.radiusInPixels = 4,
  });

  @override
  State<BloomChart> createState() => _BloomChartState();
}

class _BloomChartState extends State<BloomChart> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? 200;
    final showAxis = widget.showXAxis || widget.showYAxis;
    const axisHeight = 22.0;

    final chart = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.legendPosition == BloomLegendPosition.top && widget.showLegend)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChartLegend(data: widget.data, config: widget.config),
          ),
        SizedBox(
          height: h,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.showTooltip ? (d) => _updateActive(d, h) : null,
            onTapUp: (_) => setState(() => _activeIndex = null),
            onHorizontalDragStart: widget.showTooltip ? (d) => _updateActive(d, h) : null,
            onHorizontalDragUpdate: widget.showTooltip ? (d) => _updateActive(d, h) : null,
            onHorizontalDragEnd: (_) => setState(() => _activeIndex = null),
            child: CustomPaint(
              painter: _ChartPainter(
                data: widget.data,
                type: widget.type,
                colors: context.bloomColors,
                radius: context.bloomRadius,
                activeIndex: widget.showTooltip ? _activeIndex : null,
                showGrid: widget.showGrid,
                showXAxis: widget.showXAxis,
                showYAxis: widget.showYAxis,
                radiusInPixels: widget.radiusInPixels,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        if (showAxis && widget.showXAxis)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              height: axisHeight,
              child: Row(
                children: [
                  if (widget.showYAxis) const SizedBox(width: 34),
                  Expanded(
                    child: _XAxisLabels(data: widget.data, type: widget.type, activeIndex: _activeIndex),
                  ),
                ],
              ),
            ),
          ),
        if (widget.legendPosition == BloomLegendPosition.bottom && widget.showLegend)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _ChartLegend(data: widget.data, config: widget.config),
          ),
      ],
    );

    if (!widget.showTooltip) return chart;

    return Stack(
      children: [
        chart,
        if (_activeIndex != null && widget.type != BloomChartType.pie && widget.type != BloomChartType.radial)
          Positioned(
            top: 0,
            left: 8,
            child: _ChartTooltip(
              data: widget.data,
              index: _activeIndex!,
              type: widget.type,
              config: widget.config,
            ),
          ),
      ],
    );
  }

  void _updateActive(dynamic details, double height) {
    double local;
    if (details is TapDownDetails) {
      local = details.localPosition.dx;
    } else if (details is DragStartDetails) {
      local = details.localPosition.dx;
    } else if (details is DragUpdateDetails) {
      local = details.localPosition.dx;
    } else {
      return;
    }
    final n = widget.data.labels.length;
    if (n == 0) return;
    final w = context.size?.width ?? 0;
    if (w <= 0) return;
    final actualWidth = widget.showXAxis || widget.showYAxis ? w - 34 - 8 : w;
    final ratio = ((local / actualWidth).clamp(0.0, 1.0));
    final index = (ratio * (n - 1)).round().clamp(0, n - 1);
    setState(() => _activeIndex = index);
  }
}

class _XAxisLabels extends StatelessWidget {
  final BloomChartData data;
  final BloomChartType type;
  final int? activeIndex;

  const _XAxisLabels({required this.data, required this.type, this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    return Row(
      children: List.generate(data.labels.length, (i) {
        final width = 1 / data.labels.length;
        return Expanded(
          flex: (width * 10000).round(),
          child: Text(
            data.labels[i],
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: activeIndex == i ? colors.textPrimary : colors.textTertiary,
              fontSize: 11,
              fontFamily: context.bloomTypography.sans,
            ),
          ),
        );
      }),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final BloomChartData data;
  final Map<String, BloomChartConfig>? config;

  const _ChartLegend({required this.data, this.config});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: data.series.map((series) {
        final c = config?[series.name];
        final color = series.color ?? _seriesColor(colors, data.series.indexOf(series));
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(
              c?.label ?? series.name,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ChartTooltip extends StatelessWidget {
  final BloomChartData data;
  final int index;
  final BloomChartType type;
  final Map<String, BloomChartConfig>? config;

  const _ChartTooltip({required this.data, required this.index, required this.type, this.config});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.textPrimary,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BloomShadows.s2],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.labels[index],
            style: TextStyle(color: colors.textTertiary, fontSize: 11, fontFamily: context.bloomTypography.sans, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          for (var s = 0; s < data.series.length; s++) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: data.series[s].color ?? _seriesColor(colors, s)),
                const SizedBox(width: 5),
                Text(
                  data.series[s].name,
                  style: TextStyle(color: colors.textTertiary, fontSize: 11, fontFamily: context.bloomTypography.sans),
                ),
                const SizedBox(width: 8),
                Text(
                  '${data.series[s].values[index]}',
                  style: TextStyle(color: colors.textPrimary, fontSize: 11, fontFamily: context.bloomTypography.mono, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

Color _seriesColor(BloomColorScheme colors, int index) {
  return switch (index % 5) {
    0 => colors.chart1,
    1 => colors.chart2,
    2 => colors.chart3,
    3 => colors.chart4,
    _ => colors.chart5,
  };
}

class _ChartPainter extends CustomPainter {
  final BloomChartData data;
  final BloomChartType type;
  final BloomColorScheme colors;
  final BloomRadius radius;
  final int? activeIndex;
  final bool showGrid;
  final bool showXAxis;
  final bool showYAxis;
  final int radiusInPixels;

  _ChartPainter({
    required this.data,
    required this.type,
    required this.colors,
    required this.radius,
    this.activeIndex,
    this.showGrid = true,
    this.showXAxis = true,
    this.showYAxis = true,
    this.radiusInPixels = 4,
  });

  static const double _leftPad = 34;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.labels.isEmpty || data.series.isEmpty) return;

    switch (type) {
      case BloomChartType.bar:
        _paintBar(canvas, size);
      case BloomChartType.line:
        _paintLine(canvas, size);
      case BloomChartType.area:
        _paintArea(canvas, size);
      case BloomChartType.pie:
        _paintPie(canvas, size);
      case BloomChartType.radar:
        _paintRadar(canvas, size);
      case BloomChartType.radial:
        _paintRadial(canvas, size);
    }
  }

  double _plotWidth(Size size) => size.width - (showYAxis ? _leftPad + 8 : 0);
  double _plotLeft(Size size) => showYAxis ? _leftPad : 0;

  void _paintGrid(Canvas canvas, Size size) {
    if (!showGrid) return;
    final gridPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final left = _plotLeft(size);
    final n = data.labels.length;
    if (n < 2) return;
    final step = _plotWidth(size) / (n - 1);
    for (var i = 0; i < n; i++) {
      final x = left + i * step;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height - 8), gridPaint);
    }
  }

  void _paintBar(Canvas canvas, Size size) {
    final n = data.labels.length;
    if (n == 0) return;
    _paintGrid(canvas, size);
    final seriesCount = data.series.length;
    final groupWidth = _plotWidth(size) / n;
    final barWidth = (groupWidth * 0.6) / seriesCount;
    final maxVal = _maxValue();
    if (maxVal == 0) return;
    final bottom = size.height - 8;
    final left = _plotLeft(size);

    for (var s = 0; s < seriesCount; s++) {
      final series = data.series[s];
      final seriesColor = series.color ?? _seriesColor(colors, s);
      final paint = Paint()..color = seriesColor;

      for (var i = 0; i < n; i++) {
        final val = series.values[i].toDouble();
        final barH = (val / maxVal) * (bottom - 8);
        final y = bottom - barH;
        final x = left + i * groupWidth + (groupWidth - barWidth * seriesCount) / 2 + s * barWidth;
        final r = radiusInPixels < 1 ? 0.0 : radiusInPixels.toDouble();
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, y, barWidth - 2, barH),
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r),
          ),
          paint,
        );
        if (activeIndex != null && (activeIndex!) == i) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(x - 2, y - 2, barWidth + 2, barH + 4),
              topLeft: Radius.circular(r + 2),
              topRight: Radius.circular(r + 2),
            ),
            Paint()
              ..color = colors.ring.withValues(alpha: 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  void _paintLine(Canvas canvas, Size size) {
    final n = data.labels.length;
    if (n < 2) return;
    _paintGrid(canvas, size);
    final maxVal = _maxValue();
    if (maxVal == 0) return;
    final top = 6.0;
    final bottom = size.height - 8;
    final chartH = bottom - top;
    final left = _plotLeft(size);
    final stepX = _plotWidth(size) / (n - 1);

    for (var s = 0; s < data.series.length; s++) {
      final series = data.series[s];
      final seriesColor = series.color ?? _seriesColor(colors, s);
      final paint = Paint()
        ..color = seriesColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      for (var i = 0; i < n; i++) {
        final x = left + i * stepX;
        final y = bottom - (series.values[i].toDouble() / maxVal) * chartH;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);

      for (var i = 0; i < n; i++) {
        final x = left + i * stepX;
        final y = bottom - (series.values[i].toDouble() / maxVal) * chartH;
        final isActive = activeIndex == i;
        canvas.drawCircle(Offset(x, y), isActive ? 4.5 : 3, Paint()..color = colors.surface1);
        canvas.drawCircle(Offset(x, y), isActive ? 3.5 : 2.5, paint);
      }
    }
  }

  void _paintArea(Canvas canvas, Size size) {
    final n = data.labels.length;
    if (n < 2) return;
    _paintGrid(canvas, size);
    final maxVal = _maxValue();
    if (maxVal == 0) return;
    final top = 6.0;
    final bottom = size.height - 8;
    final chartH = bottom - top;
    final left = _plotLeft(size);
    final stepX = _plotWidth(size) / (n - 1);

    for (var s = 0; s < data.series.length; s++) {
      final series = data.series[s];
      final seriesColor = series.color ?? _seriesColor(colors, s);

      final linePaint = Paint()
        ..color = seriesColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [seriesColor.withValues(alpha: 0.3), seriesColor.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(left, top, _plotWidth(size), chartH));

      final path = Path();
      for (var i = 0; i < n; i++) {
        final x = left + i * stepX;
        final y = bottom - (series.values[i].toDouble() / maxVal) * chartH;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.lineTo(left + (n - 1) * stepX, bottom);
      path.lineTo(left, bottom);
      path.close();
      canvas.drawPath(path, fillPaint);

      final linePath = Path();
      for (var i = 0; i < n; i++) {
        final x = left + i * stepX;
        final y = bottom - (series.values[i].toDouble() / maxVal) * chartH;
        if (i == 0) {
          linePath.moveTo(x, y);
        } else {
          linePath.lineTo(x, y);
        }
      }
      canvas.drawPath(linePath, linePaint);

      for (var i = 0; i < n; i++) {
        final x = left + i * stepX;
        final y = bottom - (series.values[i].toDouble() / maxVal) * chartH;
        final isActive = activeIndex == i;
        canvas.drawCircle(Offset(x, y), isActive ? 4.5 : 3, Paint()..color = colors.surface1);
        canvas.drawCircle(Offset(x, y), isActive ? 3.5 : 2.5, linePaint);
      }
    }
  }

  void _paintPie(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide / 2) - 16;
    if (r <= 0) return;

    final allVals = <num>[];
    for (final s in data.series) allVals.addAll(s.values);
    if (allVals.isEmpty) return;
    final total = allVals.fold<num>(0, (a, b) => a + b).toDouble();
    if (total == 0) return;

    var startAngle = -1.5708;
    var idx = 0;
    for (var s = 0; s < data.series.length; s++) {
      for (var v = 0; v < data.series[s].values.length; v++) {
        final val = data.series[s].values[v].toDouble();
        final sweep = (val / total) * 6.28319;
        final color = data.series[s].color ?? _seriesColor(colors, idx);
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawArc(Rect.fromCircle(center: center, radius: r), startAngle, sweep, true, paint);
        canvas.drawArc(Rect.fromCircle(center: center, radius: r), startAngle, sweep, true, Paint()..color = colors.surface1..strokeWidth = 2..style = PaintingStyle.stroke);
        startAngle += sweep;
        idx++;
      }
    }
  }

  void _paintRadial(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide / 2) - 16;
    if (r <= 0) return;

    final maxVal = _maxValue();
    if (maxVal == 0) return;

    for (var s = 0; s < data.series.length; s++) {
      final series = data.series[s];
      if (series.values.isEmpty) continue;
      final val = series.values[0].toDouble();
      final seriesColor = series.color ?? _seriesColor(colors, s);

      canvas.drawCircle(center, r, Paint()..color = colors.surface2.withValues(alpha: 0.5));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -1.5708,
        6.28319 * (val / maxVal),
        true,
        Paint()..color = seriesColor,
      );
    }
  }

  void _paintRadar(Canvas canvas, Size size) {
    final n = data.labels.length;
    if (n < 2) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radiusDim = (size.shortestSide / 2) - 24;
    if (radiusDim <= 0) return;
    final maxVal = _maxValue();
    if (maxVal == 0) return;
    final angleStep = 6.28319 / n;

  Offset point(int i, double f) {
    final angle = -1.5708 + i * angleStep;
    return center + Offset(math.cos(angle) * radiusDim * f, math.sin(angle) * radiusDim * f);
  }

    // grid: rings + spokes
    final gridPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      final f = ring / 4;
      for (var i = 0; i < n; i++) {
        final p = point(i, f);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    for (var i = 0; i < n; i++) {
      final p = point(i, 1.0);
      canvas.drawLine(center, p, gridPaint);
    }

    for (var s = 0; s < data.series.length; s++) {
      final series = data.series[s];
      final seriesColor = series.color ?? _seriesColor(colors, s);
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = point(i, series.values[i].toDouble() / maxVal);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = seriesColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = seriesColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (var i = 0; i < n; i++) {
        final p = point(i, series.values[i].toDouble() / maxVal);
        canvas.drawCircle(p, 3, Paint()..color = seriesColor);
      }
    }
  }

  double _maxValue() {
    double m = 0;
    for (final s in data.series) {
      for (final v in s.values) {
        if (v.toDouble() > m) m = v.toDouble();
      }
    }
    return m;
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
