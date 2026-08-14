// lib/src/primitives/chart.dart
import 'package:flutter/material.dart';
import '../theme/bloom_color_scheme.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomChartConfig {
  final String label;
  final Color? color;

  const BloomChartConfig({required this.label, this.color});
}

enum BloomChartType { area, bar, line, pie, radial }

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

class BloomChart extends StatelessWidget {
  final BloomChartData data;
  final BloomChartType type;
  final double? height;
  final bool showLegend;
  final bool showTooltip;
  final Map<String, BloomChartConfig>? config;

  const BloomChart({
    super.key,
    required this.data,
    this.type = BloomChartType.bar,
    this.height,
    this.showLegend = true,
    this.showTooltip = true,
    this.config,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? 200;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: h,
          child: CustomPaint(
            painter: _ChartPainter(
              data: data,
              type: type,
              colors: context.bloomColors,
              radius: context.bloomRadius,
            ),
            size: Size.infinite,
          ),
        ),
        if (showLegend)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _ChartLegend(data: data, config: config),
          ),
      ],
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

  _ChartPainter({required this.data, required this.type, required this.colors, required this.radius});

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
      case BloomChartType.radial:
        _paintRadial(canvas, size);
    }
  }

  void _paintBar(Canvas canvas, Size size) {
    final n = data.labels.length;
    if (n == 0) return;
    final seriesCount = data.series.length;
    final groupWidth = size.width / n;
    final barWidth = (groupWidth * 0.7) / seriesCount;
    final maxVal = _maxValue();
    if (maxVal == 0) return;

    for (var s = 0; s < seriesCount; s++) {
      final series = data.series[s];
      final seriesColor = series.color ?? _seriesColor(colors, s);
      final paint = Paint()..color = seriesColor;

      for (var i = 0; i < n; i++) {
        final x = i * groupWidth + (groupWidth - barWidth * seriesCount) / 2 + s * barWidth;
        final val = series.values[i].toDouble();
        final barH = (val / maxVal) * (size.height - 24);
        final y = size.height - barH - 16;
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x, y, barWidth - 2, barH), topLeft: Radius.circular(3), topRight: Radius.circular(3)),
          paint,
        );
      }
    }
  }

  void _paintLine(Canvas canvas, Size size) {
    final n = data.labels.length;
    if (n < 2) return;
    final maxVal = _maxValue();
    if (maxVal == 0) return;
    final top = 8.0;
    final bottom = size.height - 16;
    final chartH = bottom - top;
    final stepX = size.width / (n - 1);

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
        final x = i * stepX;
        final y = bottom - (series.values[i].toDouble() / maxVal) * chartH;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);

      for (var i = 0; i < n; i++) {
        final x = i * stepX;
        final y = bottom - (series.values[i].toDouble() / maxVal) * chartH;
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = colors.surface1);
        canvas.drawCircle(Offset(x, y), 2.5, paint);
      }
    }
  }

  void _paintArea(Canvas canvas, Size size) {
    final n = data.labels.length;
    if (n < 2) return;
    final maxVal = _maxValue();
    if (maxVal == 0) return;
    final top = 8.0;
    final bottom = size.height - 16;
    final chartH = bottom - top;
    final stepX = size.width / (n - 1);

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
        ).createShader(Rect.fromLTWH(0, top, size.width, chartH));

      final path = Path();
      for (var i = 0; i < n; i++) {
        final x = i * stepX;
        final y = bottom - (series.values[i].toDouble() / maxVal) * chartH;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.lineTo((n - 1) * stepX, bottom);
      path.lineTo(0, bottom);
      path.close();
      canvas.drawPath(path, fillPaint);

      final linePath = Path();
      for (var i = 0; i < n; i++) {
        final x = i * stepX;
        final y = bottom - (series.values[i].toDouble() / maxVal) * chartH;
        if (i == 0) {
          linePath.moveTo(x, y);
        } else {
          linePath.lineTo(x, y);
        }
      }
      canvas.drawPath(linePath, linePaint);
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
      final fraction = val / maxVal;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -1.5708,
        6.28319 * fraction,
        true,
        Paint()..color = seriesColor,
      );
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
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => oldDelegate.data != data || oldDelegate.type != type;
}
