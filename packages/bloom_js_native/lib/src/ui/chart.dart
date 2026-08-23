import 'dart:math' as math;
import '../framework.dart';
import 'cn.dart';

/// Data point for a simple bar chart.
typedef ChartDataPoint = ({String label, double value});

/// Simple pure-SVG bar chart component.
///
/// Renders a lightweight, high-performance bar chart without external charting dependencies.
BloomNode barChart({
  required List<ChartDataPoint> data,
  double? maxValue,
  double height = 160,
  String? color,
  String extraClassName = '',
}) {
  if (data.isEmpty) {
    return Div(
      className: cn([
        'h-40 flex items-center justify-center text-xs text-[var(--text-muted)] border border-dashed border-[var(--border)] rounded-[var(--radius-md)]',
        extraClassName,
      ]),
      text: 'No data available',
    );
  }

  final computedMax = maxValue ??
      (data.map((d) => d.value).reduce(math.max) > 0
          ? data.map((d) => d.value).reduce(math.max)
          : 1.0);

  final chartHeight = height;
  final plotHeight = chartHeight - 28.0;
  final barWidth = 24.0;
  final gap = 16.0;
  final totalWidth = (data.length * (barWidth + gap)) + gap;

  final barColor = color ?? 'var(--primary)';

  final bars = <BloomNode>[];

  // Grid line at bottom of plot
  bars.add(El(
    'line',
    attrs: {
      'x1': '0',
      'y1': '$plotHeight',
      'x2': '$totalWidth',
      'y2': '$plotHeight',
      'stroke': 'var(--border)',
      'stroke-width': '1',
    },
  ));

  for (var i = 0; i < data.length; i++) {
    final item = data[i];
    final normalized = (item.value / computedMax).clamp(0.0, 1.0);
    final barH = (normalized * (plotHeight - 10.0)).clamp(2.0, plotHeight);
    final x = gap + i * (barWidth + gap);
    final y = plotHeight - barH;

    // Bar rectangle
    bars.add(El(
      'rect',
      attrs: {
        'x': '$x',
        'y': '$y',
        'width': '$barWidth',
        'height': '$barH',
        'rx': '3',
        'fill': barColor,
      },
    ));

    // Label under bar
    bars.add(El(
      'text',
      attrs: {
        'x': '${x + barWidth / 2}',
        'y': '${chartHeight - 8}',
        'text-anchor': 'middle',
        'font-size': '10',
        'font-family': 'var(--font-sans)',
        'fill': 'var(--text-muted)',
      },
      text: item.label,
    ));
  }

  return Div(
    attrs: const {'data-slot': 'bar-chart'},
    className: cn([
      'w-full overflow-x-auto p-3 bg-[var(--card)] border border-[var(--border)] rounded-[var(--radius-lg)] shadow-[var(--shadow-card)]',
      extraClassName,
    ]),
    children: [
      El(
        'svg',
        attrs: {
          'viewBox': '0 0 $totalWidth $chartHeight',
          'width': '$totalWidth',
          'height': '$chartHeight',
          'aria-label': 'Bar chart',
        },
        className: 'overflow-visible',
        children: bars,
      ),
    ],
  );
}

/// Lightweight inline SVG sparkline component.
///
/// Renders a concise trend visualization polyline.
BloomNode sparkline({
  required List<double> values,
  double width = 120,
  double height = 32,
  String? color,
  String extraClassName = '',
}) {
  if (values.isEmpty) {
    return Div(
      className: cn(['h-8 w-28 bg-[var(--bg-muted)] rounded', extraClassName]),
    );
  }

  final minVal = values.reduce(math.min);
  final maxVal = values.reduce(math.max);
  final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

  final padding = 3.0;
  final availableW = width - (padding * 2);
  final availableH = height - (padding * 2);

  final stepX = values.length > 1 ? availableW / (values.length - 1) : 0.0;

  final points = <String>[];
  for (var i = 0; i < values.length; i++) {
    final x = padding + (i * stepX);
    final normalized = (values[i] - minVal) / range;
    final y = height - padding - (normalized * availableH);
    points.add('${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}');
  }

  final pointsStr = points.join(' ');
  final lineColor = color ?? 'var(--primary)';

  return El(
    'svg',
    attrs: {
      'data-slot': 'sparkline',
      'viewBox': '0 0 $width $height',
      'width': '$width',
      'height': '$height',
      'aria-hidden': 'true',
    },
    className: cn(['shrink-0 overflow-visible', extraClassName]),
    children: [
      El(
        'polyline',
        attrs: {
          'points': pointsStr,
          'fill': 'none',
          'stroke': lineColor,
          'stroke-width': '2',
          'stroke-linecap': 'round',
          'stroke-linejoin': 'round',
        },
      ),
    ],
  );
}
