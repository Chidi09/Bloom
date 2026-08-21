import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('Chart')
external JSObject _createChart(web.HTMLCanvasElement canvas, JSObject config);

class ChartJsPlugin {
  static void renderPerformanceChart(web.HTMLCanvasElement canvas) {
    try {
      final config = <String, dynamic>{
        'type': 'bar',
        'data': {
          'labels': ['Bloom JS Native', 'Next.js (React 19)', 'Nuxt 3 (Vue 3)', 'Angular SSR', 'SvelteKit'],
          'datasets': [
            {
              'label': 'SSR Response Time (ms) — Lower is better',
              'data': [0.4, 18.2, 14.5, 26.0, 6.8],
              'backgroundColor': 'rgba(99, 102, 241, 0.85)',
              'borderColor': 'rgba(99, 102, 241, 1)',
              'borderWidth': 1,
              'borderRadius': 6,
            },
            {
              'label': 'Client Bundle Baseline (kB gzip) — Lower is better',
              'data': [20.1, 98.4, 62.0, 145.0, 28.5],
              'backgroundColor': 'rgba(139, 92, 246, 0.75)',
              'borderColor': 'rgba(139, 92, 246, 1)',
              'borderWidth': 1,
              'borderRadius': 6,
            },
          ],
        },
        'options': {
          'responsive': true,
          'maintainAspectRatio': false,
          'plugins': {
            'legend': {
              'labels': {
                'color': '#A1A1AA',
                'font': {'family': 'JetBrains Mono', 'size': 11},
              },
            },
            'tooltip': {
              'backgroundColor': '#14141A',
              'titleColor': '#FFFFFF',
              'bodyColor': '#A1A1AA',
              'borderColor': '#27272A',
              'borderWidth': 1,
            },
          },
          'scales': {
            'x': {
              'grid': {'color': 'rgba(255, 255, 255, 0.05)'},
              'ticks': {
                'color': '#A1A1AA',
                'font': {'family': 'Plus Jakarta Sans', 'size': 12, 'weight': '600'},
              },
            },
            'y': {
              'grid': {'color': 'rgba(255, 255, 255, 0.05)'},
              'ticks': {
                'color': '#71717A',
                'font': {'family': 'JetBrains Mono', 'size': 11},
              },
            },
          },
        },
      }.jsify() as JSObject;

      _createChart(canvas, config);
    } catch (_) {}
  }
}
