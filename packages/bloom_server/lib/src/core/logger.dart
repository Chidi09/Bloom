// lib/src/core/logger.dart

/// Log severity levels for Bloom applications.
enum BloomLogLevel {
  /// Verbose diagnostic messages.
  debug(0, 'DEBUG', '\x1B[36m'), // Cyan
  /// Normal operational messages.
  info(1, 'INFO', '\x1B[32m'),   // Green
  /// Warning messages for non-fatal issues.
  warn(2, 'WARN', '\x1B[33m'),   // Yellow
  /// Error messages for failures and unhandled exceptions.
  error(3, 'ERROR', '\x1B[31m'), // Red
  /// Disables all logging output.
  none(4, 'NONE', '');

  /// Numeric priority used for severity comparison.
  final int priority;

  /// String label displayed in formatted log output.
  final String label;

  /// ANSI color escape sequence for terminal output.
  final String ansiColor;

  const BloomLogLevel(this.priority, this.label, this.ansiColor);
}

/// Callback signature for handling formatted log line outputs.
typedef BloomLogWriter = void Function(String message);

/// Standardized structured logging system for Bloom.
class BloomLogger {
  /// Context tag identifying the subsystem or module producing the logs.
  final String context;

  /// Current minimum severity level required for a message to be logged.
  BloomLogLevel level;

  /// Output destination function for formatted log lines.
  BloomLogWriter writer;

  static const String _resetColor = '\x1B[0m';
  static const String _grayColor = '\x1B[90m';

  /// Creates a [BloomLogger] with an optional [context], minimum [level], and log [writer].
  BloomLogger({
    this.context = 'BLOOM',
    this.level = BloomLogLevel.debug,
    this.writer = print,
  });

  /// Create a child logger with a sub-context appended to this logger's context.
  BloomLogger child(String subContext) {
    final newContext = context.isEmpty ? subContext : '$context:$subContext';
    return BloomLogger(
      context: newContext,
      level: level,
      writer: writer,
    );
  }

  /// Logs a [message] at the [BloomLogLevel.debug] level with optional [error] and [stackTrace].
  void debug(dynamic message, [Object? error, StackTrace? stackTrace]) {
    _log(BloomLogLevel.debug, message, error, stackTrace);
  }

  /// Logs a [message] at the [BloomLogLevel.info] level with optional [error] and [stackTrace].
  void info(dynamic message, [Object? error, StackTrace? stackTrace]) {
    _log(BloomLogLevel.info, message, error, stackTrace);
  }

  /// Logs a [message] at the [BloomLogLevel.warn] level with optional [error] and [stackTrace].
  void warn(dynamic message, [Object? error, StackTrace? stackTrace]) {
    _log(BloomLogLevel.warn, message, error, stackTrace);
  }

  /// Logs a [message] at the [BloomLogLevel.error] level with optional [error] and [stackTrace].
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
