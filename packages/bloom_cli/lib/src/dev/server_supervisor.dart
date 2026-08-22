// lib/src/dev/server_supervisor.dart
import 'dart:async';
import 'dart:io';

/// Supervised Dart process manager for Bloom server backends.
/// Provides <80ms restart times by killing and re-spawning the child process
/// rather than waiting for a graceful shutdown sequence.
class BloomServerSupervisor {
  /// Dart entry file executed as `dart run <entryFile>`.
  final File entryFile;

  /// Additional arguments forwarded to the subprocess.
  final List<String> args;

  /// Minimum time to wait after kill before re-spawning. Defaults to 80ms.
  final Duration restartDebounce;

  Process? _process;
  bool _stopped = false;
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final List<StreamSubscription<String>> _outputSubs = [];

  BloomServerSupervisor({
    required this.entryFile,
    this.args = const [],
    this.restartDebounce = const Duration(milliseconds: 80),
  });

  /// Whether a supervised process is currently running.
  bool get isRunning => _process != null && !_stopped;

  /// PID of the current supervised process, or `null` if not running.
  int? get currentPid => _process?.pid;

  /// Broadcast stream of combined stdout+stderr lines from the supervised process.
  Stream<String> get onOutput => _outputController.stream;

  /// Starts the supervised server process.
  Future<void> start() async {
    _stopped = false;
    _process = await Process.start(
      'dart',
      ['run', entryFile.path, ...args],
      runInShell: false,
    );
    _outputSubs.add(_process!.stdout
        .transform(const SystemEncoding().decoder)
        .listen((line) {
      if (!_outputController.isClosed) _outputController.add(line);
    }));
    _outputSubs.add(_process!.stderr
        .transform(const SystemEncoding().decoder)
        .listen((line) {
      if (!_outputController.isClosed) _outputController.add(line);
    }));
  }

  /// Kills the current process and starts a fresh one after [restartDebounce].
  Future<void> restart({String? reason}) async {
    if (_stopped) return;
    await _killCurrent();
    await Future.delayed(restartDebounce);
    await start();
  }

  /// Permanently stops the supervised process.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _killCurrent();
    if (!_outputController.isClosed) {
      await _outputController.close();
    }
  }

  Future<void> _killCurrent() async {
    final proc = _process;
    _process = null;
    for (final sub in _outputSubs) {
      await sub.cancel();
    }
    _outputSubs.clear();
    if (proc != null) {
      proc.kill(ProcessSignal.sigterm);
      await proc.exitCode.timeout(
        const Duration(milliseconds: 200),
        onTimeout: () {
          proc.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
  }
}
