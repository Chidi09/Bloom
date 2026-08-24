// lib/src/commands/insights_command.dart
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Command that queries and displays recent HTTP request logs and timing insights from a running Bloom dev server.
///
/// Can query a running dev server on localhost or a remote instance via `--url`.
///
/// Example:
/// ```
/// bloom insights
/// bloom insights --limit 50 --json
/// bloom insights --url http://localhost:8080
/// ```
class InsightsCommand extends Command<int> {
  @override
  final String name = 'insights';

  @override
  final String description =
      'Queries and displays recent HTTP request logs and timing insights from a running Bloom dev server.';

  InsightsCommand() {
    argParser
      ..addOption(
        'url',
        help: 'Explicit base URL of the running Bloom dev server (e.g. http://localhost:8080).',
      )
      ..addOption(
        'limit',
        help: 'Maximum number of recent requests to display.',
        defaultsTo: '20',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print raw JSON response instead of formatted table.',
      )
      ..addOption(
        'project-dir',
        help: 'Explicit path to the Bloom project directory.',
      );
  }

  @override
  Future<int> run() async {
    final limitStr = argResults?['limit'] as String? ?? '20';
    final limit = int.tryParse(limitStr) ?? 20;
    final isJson = argResults?['json'] == true;
    final explicitUrl = argResults?['url'] as String?;

    Map<String, dynamic>? data;

    if (explicitUrl != null && explicitUrl.trim().isNotEmpty) {
      var baseUrl = explicitUrl.trim();
      if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
        baseUrl = 'http://$baseUrl';
      }
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      final uri = Uri.tryParse('$baseUrl/__insights?limit=$limit');
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        print(Ansi.error('Invalid URL provided: "$explicitUrl". Expected an http:// or https:// URL.'));
        return 1;
      }
      data = await _fetchInsights(uri);
      if (data == null) {
        print(Ansi.error('Failed to reach Bloom dev server at $explicitUrl. Make sure `bloom dev` is running.'));
        return 1;
      }
    } else {
      final projectDir = argResults?['project-dir'] != null
          ? Directory(argResults!['project-dir'] as String)
          : Directory.current;
      final project = BloomProject.find(projectDir);

      int? configPort;
      if (project != null && project.bloomYamlFile.existsSync()) {
        try {
          final config = project.loadBloomConfig();
          final pVal = config['port'] ??
              (config['devServer'] is Map ? config['devServer']['port'] : null);
          if (pVal is int) {
            configPort = pVal;
          } else if (pVal is String) {
            configPort = int.tryParse(pVal);
          }
        } catch (_) {}
      }

      final portsToScan = <int>[];
      if (configPort != null) {
        portsToScan.add(configPort);
      }
      for (var p = 8080; p <= 8090; p++) {
        if (!portsToScan.contains(p)) {
          portsToScan.add(p);
        }
      }

      for (final port in portsToScan) {
        final uri = Uri.parse('http://localhost:$port/__insights?limit=$limit');
        data = await _fetchInsights(uri, timeout: const Duration(milliseconds: 500));
        if (data != null) {
          break;
        }
      }

      if (data == null) {
        print(Ansi.error(
          'Could not connect to a running Bloom dev server on ports 8080-8090. '
          'Make sure `bloom dev` is running, or specify --url explicitly.',
        ));
        return 1;
      }
    }

    if (isJson) {
      print(const JsonEncoder.withIndent('  ').convert(data));
      return 0;
    }

    final rawRequests = data['requests'];
    final requests = rawRequests is List ? rawRequests : [];
    final total = data['total'] is int ? data['total'] as int : requests.length;

    final visibleRequests = requests.take(limit).toList();

    print(Ansi.boldText('Recent requests (showing ${visibleRequests.length} of $total):'));

    for (final item in visibleRequests) {
      if (item is! Map) continue;
      final method = (item['method']?.toString() ?? 'GET').padRight(7);
      final path = item['path']?.toString() ?? '/';
      final statusCode = item['statusCode'] is int ? item['statusCode'] as int : 200;
      final durationMs = item['durationMs'] ?? 0;

      final String statusStr;
      if (statusCode >= 200 && statusCode < 300) {
        statusStr = Ansi.success('$statusCode');
      } else if (statusCode >= 300 && statusCode < 500) {
        statusStr = Ansi.warn('$statusCode');
      } else {
        statusStr = Ansi.error('$statusCode');
      }

      print('  $method ${path.padRight(30)} $statusStr  ${durationMs}ms');
    }

    return 0;
  }

  Future<Map<String, dynamic>?> _fetchInsights(
    Uri uri, {
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode == HttpStatus.ok) {
        final bodyStr = await utf8.decodeStream(response).timeout(timeout);
        final json = jsonDecode(bodyStr);
        if (json is Map<String, dynamic>) {
          return json;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
