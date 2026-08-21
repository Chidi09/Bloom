import 'dart:async';
import 'package:bloom_js_native/bloom_js_native.dart';
import '../plugins/confetti.dart';

class BenchmarkItem {
  final int id;
  final int value;
  final int metric;

  const BenchmarkItem({
    required this.id,
    required this.value,
    required this.metric,
  });
}

class ShowcaseStore {
  static final ShowcaseStore instance = ShowcaseStore._();
  ShowcaseStore._() {
    _startBenchmarkTicker();
  }

  // Active Code Showcase Tab
  final activeTab = signal<String>('main.dart');

  // Benchmark Signal State
  final nodeCount = signal<int>(36);
  final fps = signal<int>(60);
  final patchLatencyMs = signal<double>(0.08);
  final patchesPerSec = signal<int>(1080);
  final benchmarkItems = signal<List<BenchmarkItem>>(List.generate(
    36,
    (i) => BenchmarkItem(id: i + 1, value: (i * 37 + 100) % 999, metric: (i * 17) % 100),
  ));
  final isBenchmarking = signal<bool>(true);

  // Notification Toast
  final toastMessage = signal<String?>(null);
  final isCopied = signal<bool>(false);

  Timer? _ticker;
  int _tickCount = 0;

  void selectTab(String tab) {
    activeTab.value = tab;
  }

  void updateNodeCount(int count) {
    nodeCount.value = count;
    benchmarkItems.value = List.generate(
      count,
      (i) => BenchmarkItem(id: i + 1, value: (i * 37 + 100) % 999, metric: (i * 17) % 100),
    );
  }

  void toggleBenchmark() {
    isBenchmarking.value = !isBenchmarking.value;
  }

  void triggerCopyCommand() {
    isCopied.value = true;
    showToast('Copied: bloom create my_app --target=web_dom');
    Confetti.burst(x: 0.5, y: 0.3);

    Future.delayed(const Duration(seconds: 3), () {
      isCopied.value = false;
    });
  }

  void showToast(String message) {
    toastMessage.value = message;
    Future.delayed(const Duration(seconds: 3), () {
      if (toastMessage.value == message) {
        toastMessage.value = null;
      }
    });
  }

  void _startBenchmarkTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 32), (_) {
      if (isBenchmarking.value) {
        _tickCount++;
        final start = Stopwatch()..start();
        final count = nodeCount.value;

        final newItems = List.generate(count, (i) {
          final val = ((_tickCount * 9) + (i * 47)) % 999;
          final metric = ((_tickCount * 3) + (i * 11)) % 100;
          return BenchmarkItem(id: i + 1, value: val, metric: metric);
        });

        benchmarkItems.value = newItems;
        start.stop();

        final elapsedMs = start.elapsedMicroseconds / 1000.0;
        patchLatencyMs.value = double.parse((elapsedMs < 0.05 ? 0.05 : elapsedMs).toStringAsFixed(2));
        patchesPerSec.value = count * 31;
      }
    });
  }

  void dispose() {
    _ticker?.cancel();
  }
}
