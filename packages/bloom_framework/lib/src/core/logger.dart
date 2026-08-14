// lib/src/core/logger.dart

/// Log severity levels for Bloom applications.
enum BloomLogLevel {
  debug(0, 'DEBUG', '\x1B[36m'), // Cyan
  info(1, 'INFO', '\x1B[32m'),   // Green
  warn(2, 'WARN', '\x1B[33m'),   // Yellow
  error(3, 'ERROR', '\x1B[31m'), // Red
  none(4, 'NONE', '');

  final int priority;
  final String label;
  final String ansiColor;
  const BloomLogLevel(this.priority, this.label, this.ansiColor);
}

typedef BloomLogWriter = void Function(String message);

/// Standardized structured logging system for Bloom.
class BloomLogger {
  final String context;
  BloomLogLevel level;
  BloomLogWriter writer;

  static const String _resetColor = '\x1B[0m';
  static const String _grayColor = '\x1B[90m';

  BloomLogger({
    this.context = 'BLOOM',
    this.level = BloomLogLevel.debug,
    this.writer = print,
  });

  /// Create a child logger with a sub-context.
  BloomLogger child(String subContext) {
    final newContext = context.isEmpty ? subContext : '$context:$subContext';
    return BloomLogger(
      context: newContext,
      level: level,
      writer: writer,
    );
  }

  void debug(dynamic message, [Object? error, StackTrace? stackTrace]) {
    _log(BloomLogLevel.debug, message, error, stackTrace);
  }

  void info(dynamic message, [Object? error, StackTrace? stackTrace]) {
    _log(BloomLogLevel.info, message, error, stackTrace);
  }

  void warn(dynamic message, [Object? error, StackTrace? stackTrace]) {
    _log(BloomLogLevel.warn, message, error, stackTrace);
  }

  void error(dynamic message, [Object? error, StackTrace? stackTrace]) {
    _log(BloomLogLevel.error, message, error, stackTrace);
  }

  void _log(
    BloomLogLevel msgLevel,
    dynamic message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (msgLevel.priority < level.priority) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final levelTag = '${msgLevel.ansiColor}[${msgLevel.label}]$_resetColor';
    final contextTag =
        context.isNotEmpty ? ' $_grayColor[$context]$_resetColor' : '';
    final logLine = '$timeStr $levelTag$contextTag $message';

    writer(logLine);

    if (error != null) {
      writer('$timeStr ${BloomLogLevel.error.ansiColor}[ERROR DETAIL]$_resetColor $error');
    }
    if (stackTrace != null) {
      writer(stackTrace.toString());
    }
  }
}

/// Global standard logger instance for Bloom framework and app.
final BloomLogger logger = BloomLogger();
