import 'dart:async';
import 'package:bloom_js_native/bloom_js_native.dart';
import '../plugins/confetti.dart';

class ShowcaseStore {
  static final ShowcaseStore instance = ShowcaseStore._();
  ShowcaseStore._() {
    _startBenchmarkTicker();
  }

  // Active Code Showcase Tab
  final activeTab = signal<String>('main.dart');

  // Benchmark Signal State
  final nodeCount = signal<int>(24);
  final fps = signal<int>(60);
  final patchLatencyMs = signal<double>(0.12);
  final benchmarkItems = signal<List<int>>(List.generate(24, (i) => i + 1));
  final isBenchmarking = signal<bool>(false);

  // Notification Toast
  final toastMessage = signal<String?>(null);
  final isCopied = signal<bool>(false);

  Timer? _ticker;

  void selectTab(String tab) {
    activeTab.value = tab;
  }

  void updateNodeCount(int count) {
    nodeCount.value = count;
    benchmarkItems.value = List.generate(count, (i) => i + 1);
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
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (isBenchmarking.value) {
        final current = benchmarkItems.value;
        final start = Stopwatch()..start();
        benchmarkItems.value = current.map((x) => (x % 99) + 1).toList();
        start.stop();
        patchLatencyMs.value = double.parse((start.elapsedMicroseconds / 1000).toStringAsFixed(2));
      }
    });
  }

  void dispose() {
    _ticker?.cancel();
  }
}
