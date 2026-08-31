// lib/src/core/logger.dart

/// Log severity levels for Bloom applications.
///
/// Log messages are filtered based on [priority]: a message is only written if
/// its level's priority is greater than or equal to the logger's active [BloomLogger.level].
enum BloomLogLevel {
  /// Verbose diagnostic messages useful during local development and debugging.
  debug(0, 'DEBUG', '\x1B[36m'), // Cyan

  /// Normal operational messages confirming routine business actions and events.
  info(1, 'INFO', '\x1B[32m'), // Green

  /// Warning messages for non-fatal issues, deprecations, or unexpected conditions.
  warn(2, 'WARN', '\x1B[33m'), // Yellow

  /// Error messages for critical failures, unhandled exceptions, and service outages.
  error(3, 'ERROR', '\x1B[31m'), // Red

  /// Disables all logging output when set as the active [BloomLogger.level].
  none(4, 'NONE', '');

  /// Numeric priority used for severity filtering and comparison.
  final int priority;

  /// String label displayed in formatted console log output.
  final String label;

  /// ANSI color escape sequence used for terminal colorization.
  final String ansiColor;

  /// Creates a [BloomLogLevel] with [priority], [label], and [ansiColor].
  const BloomLogLevel(this.priority, this.label, this.ansiColor);
}

/// Callback signature for handling formatted log line outputs.
///
/// Custom writers can redirect logs to file systems, centralized observability
/// collectors (e.g. Datadog, CloudWatch), or custom UI log viewers.
///
/// ### Example
/// ```dart
/// final logger = BloomLogger(
///   writer: (line) => logFile.writeAsStringSync('$line\n', mode: FileMode.append),
/// );
/// ```
typedef BloomLogWriter = void Function(String message);

/// Standardized structured logging system for Bloom servers, apps, and microservices.
///
/// [BloomLogger] formats log messages with timestamps, ANSI colorized severity tags,
/// hierarchical context identifiers, and structured error/stackTrace outputs.
///
/// ### Features
/// - **Hierarchical Sub-Contexts**: Create sub-loggers using [child] (e.g., `'API'` -> `'API:AUTH'`).
/// - **Configurable Severity**: Filter messages at runtime with [level].
/// - **Pluggable Output**: Intercept and redirect output lines with [writer].
///
/// ### Example
/// ```dart
/// final logger = BloomLogger(context: 'HTTP', level: BloomLogLevel.info);
///
/// logger.info('Server started on port 8080');
/// logger.debug('This message will be skipped because level is INFO');
///
/// final authLogger = logger.child('AUTH');
/// authLogger.warn('Invalid login attempt for user alice');
///
/// try {
///   throw StateError('Database connection dropped');
/// } catch (e, st) {
///   logger.error('Failed to query user', e, st);
/// }
/// ```
class BloomLogger {
  /// Context tag identifying the subsystem, module, or component producing the logs.
  final String context;

  /// Current minimum severity level required for a message to be logged.
  BloomLogLevel level;

  /// Output destination function for formatted log lines (defaults to [print]).
  BloomLogWriter writer;

  static const String _resetColor = '\x1B[0m';
  static const String _grayColor = '\x1B[90m';

  /// Creates a [BloomLogger] with an optional [context] tag, minimum severity [level], and log [writer].
  BloomLogger({
    this.context = 'BLOOM',
    this.level = BloomLogLevel.debug,
    this.writer = print,
  });

  /// Creates a child logger with [subContext] appended to this logger's [context].
  ///
  /// Inherits the current [level] and [writer] from the parent logger.
  ///
  /// ### Example
  /// ```dart
  /// final dbLogger = logger.child('DATABASE');
  /// dbLogger.info('Connected to PostgreSQL'); // logs with context [BLOOM:DATABASE]
  /// ```
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
      writer(
          '$timeStr ${BloomLogLevel.error.ansiColor}[ERROR DETAIL]$_resetColor $error');
    }
    if (stackTrace != null) {
      writer(stackTrace.toString());
    }
  }
}

/// Global standard logger instance for Bloom framework and applications.
///
/// Configured with default context `'BLOOM'` and [BloomLogLevel.debug].
final BloomLogger logger = BloomLogger();
