import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Recursive, debounced file watcher that notifies when source files change.
class BloomSourceWatcher {
  final List<Directory> directories;
  final Duration debounceDuration;
  final List<String> extensions;
  final List<String> ignorePatterns;

  final StreamController<List<FileSystemEvent>> _controller =
      StreamController<List<FileSystemEvent>>.broadcast();

  final List<StreamSubscription> _subscriptions = [];
  final Set<String> _watchedDirectories = {};
  Timer? _debounceTimer;
  final List<FileSystemEvent> _pendingEvents = [];

  BloomSourceWatcher({
    required this.directories,
    this.debounceDuration = const Duration(milliseconds: 150),
    this.extensions = const ['.dart', '.html', '.css', '.yaml', '.json', '.js'],
    this.ignorePatterns = const [
      '.git',
      '.dart_tool',
      'build',
      '.tmp',
      'vendor'
    ],
  }) {
    _startWatching();
  }

  Stream<List<FileSystemEvent>> get onChange => _controller.stream;

  void _startWatching() {
    for (final baseDir in directories) {
      if (!baseDir.existsSync()) continue;

      // Watch base dir and all subdirectories to ensure Linux inotify coverage
      final allDirs = [
        baseDir,
        ...baseDir.listSync(recursive: true).whereType<Directory>(),
      ];

      for (final dir in allDirs) {
        _watchDirectory(dir);
      }
    }
  }

  void _watchDirectory(Directory dir) {
    final normalized = p.normalize(dir.path);
    if (!_watchedDirectories.add(normalized)) return;

    final sub = dir.watch(recursive: false).listen((event) {
      // Directory watches are not recursive. Subscribe immediately when a
      // new source directory appears so a restart is not required.
      if (event is FileSystemCreateEvent) {
        final createdDir = Directory(event.path);
        if (createdDir.existsSync()) {
          _watchDirectory(createdDir);
          return;
        }
      }

      final path = event.path;

      // Check ignore patterns
      for (final pattern in ignorePatterns) {
        if (path.contains(pattern)) return;
      }

      // Check file extension
      final ext = p.extension(path).toLowerCase();
      if (extensions.isNotEmpty && !extensions.contains(ext)) return;

      _pendingEvents.add(event);

      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, () {
        if (_pendingEvents.isNotEmpty) {
          _controller.add(List.from(_pendingEvents));
          _pendingEvents.clear();
        }
      });
    });

    _subscriptions.add(sub);
  }

  void dispose() {
    _debounceTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _watchedDirectories.clear();
    _controller.close();
  }
}
