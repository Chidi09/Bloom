import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;

import 'components/benchmark.dart';
import 'components/code_showcase.dart';
import 'components/feature_grid.dart';
import 'components/footer.dart';
import 'components/hero.dart';
import 'components/interactive_sandbox.dart';
import 'components/navbar.dart';
import 'plugins/chart_js.dart';
import 'plugins/three_js.dart';
import 'state/showcase_store.dart';

void main() {
  final store = ShowcaseStore.instance;

  final app = Div(
    className: 'min-h-screen bg-[#09090B] text-zinc-100 flex flex-col justify-between selection:bg-indigo-600 selection:text-white relative',
    children: [
      // 1. Navigation Header
      NavbarComponent(store).build(),

      // 2. Main Content Sections
      Main(
        className: 'flex-1 flex flex-col',
        children: [
          HeroComponent(store).build(),
          BenchmarkComponent(store).build(),
          InteractiveSandboxComponent(store).build(),
          FeatureGridComponent().build(),
          CodeShowcaseComponent(store).build(),
        ],
      ),

      // 3. Footer
      FooterComponent().build(),

      // 4. Floating Toast Notification
      Live(() {
        final msg = store.toastMessage.value;
        if (msg == null) return const Fragment.fromList([]);

        return Div(
          className: 'fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl bg-[#14141A] border border-[#27272A] shadow-2xl flex items-center gap-3 animate-bounce',
          children: [
            Raw('<svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>'),
            Span(className: 'text-xs font-mono text-zinc-200 font-medium', text: msg),
          ],
        );
      }),
    ],
  );

  // Mount fine-grained reactive DOM tree
  mount(app, '#app');

  // Initialize Three.js hero canvas
  final canvas = web.document.getElementById('three-hero-canvas') as web.HTMLCanvasElement?;
  if (canvas != null) {
    ThreeHeroScene(canvas).init();
  }

  // Initialize Chart.js comparative performance graph
  final chartCanvas = web.document.getElementById('perf-chart') as web.HTMLCanvasElement?;
  if (chartCanvas != null) {
    ChartJsPlugin.renderPerformanceChart(chartCanvas);
  }
}
