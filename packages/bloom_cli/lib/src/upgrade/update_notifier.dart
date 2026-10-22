import 'dart:convert';
import 'dart:io';
import 'package:pub_semver/pub_semver.dart';
import '../utils/ansi.dart';
import '../version.dart';
import 'upgrade_engine.dart';

/// Fetches the latest hosted version of a package from pub.dev.
///
/// Returns `null` on network, HTTP, or response parsing failures.
Future<String?> fetchLatestPubVersion(String package) async {
  return _fetchLatestPubVersion(package)
      .timeout(const Duration(seconds: 3), onTimeout: () => null);
}

Future<String?> _fetchLatestPubVersion(String package) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client
        .getUrl(Uri.parse('https://pub.dev/api/packages/$package'))
        .timeout(const Duration(seconds: 3));
    final response = await request.close().timeout(const Duration(seconds: 3));
    if (response.statusCode != HttpStatus.ok) return null;
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 3));
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['latest'] is! Map) return null;
    final version = decoded['latest']['version'];
    return version is String && version.isNotEmpty ? version : null;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Announces a newer Bloom CLI version without affecting command execution.
class UpdateNotifier {
  final String currentVersion;
  final File cacheFile;
  final UpgradeLatestVersionFetcher fetchLatest;
  final DateTime Function() _now;
  final Duration checkInterval;
  Future<String?>? _fetch;
  String? _latest;
  bool _started = false;

  UpdateNotifier({
    required this.currentVersion,
    required this.cacheFile,
    required this.fetchLatest,
    DateTime Function()? now,
    this.checkInterval = const Duration(hours: 24),
  }) : _now = now ?? DateTime.now;

  /// Creates a notifier using the user's Bloom cache directory.
  factory UpdateNotifier.forCli() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return UpdateNotifier(
      currentVersion: bloomCliVersion,
      cacheFile: File('$home/.bloom/update-check.json'),
      fetchLatest: fetchLatestPubVersion,
    );
  }

  /// Whether the invocation is an interactive command eligible for checking.
  static bool shouldRun(
    List<String> args,
    Map<String, String> environment, {
    required bool hasTerminal,
  }) {
    if (!hasTerminal ||
        environment.containsKey('CI') ||
        environment.containsKey('BLOOM_NO_UPDATE_CHECK') ||
        args.isEmpty) {
      return false;
    }
    if (args.any((arg) =>
        arg == '--version' || arg == '-v' || arg == '--help' || arg == '-h')) {
      return false;
    }
    final command = args.firstWhere(
      (arg) => !arg.startsWith('-'),
      orElse: () => '',
    );
    return command != 'upgrade';
  }

  /// Starts a background check if the cache has expired.
  void start() {
    if (_started) return;
    _started = true;
    try {
      if (!cacheFile.existsSync()) {
        _fetch = _safeFetch();
        return;
      }
      final decoded = jsonDecode(cacheFile.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        _fetch = _safeFetch();
        return;
      }
      _latest = decoded['latest'] as String?;
      final checkedAt =
          DateTime.tryParse(decoded['checkedAt'] as String? ?? '');
      if (checkedAt == null || _now().difference(checkedAt) >= checkInterval) {
        _fetch = _safeFetch();
      }
    } catch (_) {
      _fetch = _safeFetch();
    }
  }

  /// Waits briefly for the check and returns a notice when an update exists.
  Future<String?> finish({
    Duration wait = const Duration(milliseconds: 800),
  }) async {
    try {
      final future = _fetch;
      if (future != null) {
        String? value;
        try {
          value = await future.timeout(wait);
        } on Exception {
          // Offline or slow: keep the last known version and retry after
          // [checkInterval] instead of delaying every command.
        }
        if (value != null) _latest = value;
        cacheFile.parent.createSync(recursive: true);
        cacheFile.writeAsStringSync(jsonEncode({
          'checkedAt': _now().toIso8601String(),
          'latest': _latest,
        }));
      }
      final latest = _version(_latest);
      final current = _version(currentVersion);
      if (latest == null || current == null || latest <= current) return null;
      return Ansi.warn(
        'Bloom $_latest is available (you have $currentVersion). '
        'Run `bloom upgrade` to update the CLI and your project.',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _safeFetch() async {
    try {
      return await fetchLatest('bloom_cli');
    } catch (_) {
      return null;
    }
  }
}

Version? _version(String? value) {
  if (value == null) return null;
  try {
    return Version.parse(value);
  } catch (_) {
    return null;
  }
}
