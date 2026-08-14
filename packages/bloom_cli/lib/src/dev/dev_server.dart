// lib/src/dev/dev_server.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'mdns_discovery.dart';
import 'qr_renderer.dart';

/// Lightweight HTTP development server powering Bloom Go and wireless developer workflows.
class BloomDevServer {
  final BloomProject project;
  final int preferredPort;
  HttpServer? _server;
  MdnsDiscovery? _mdns;
  late String _localIp;
  int _actualPort = 8080;
  final List<Map<String, dynamic>> _pairedDevices = [];
  final DateTime _startedAt = DateTime.now();

  BloomDevServer(this.project, {this.preferredPort = 8080});

  String get localIp => _localIp;
  int get port => _actualPort;
  String get devServerUri => 'bloom://dev-server?host=$_localIp&port=$_actualPort&id=${project.projectName}';
  String get httpUrl => 'http://$_localIp:$_actualPort';
  List<Map<String, dynamic>> get pairedDevices => List.unmodifiable(_pairedDevices);

  /// Start development server and discovery beacons.
  Future<void> start() async {
    _localIp = await MdnsDiscovery.getLocalIp();

    int portToTry = preferredPort;
    while (_server == null && portToTry < preferredPort + 50) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, portToTry);
        _actualPort = portToTry;
      } catch (_) {
        portToTry++;
      }
    }

    if (_server == null) {
      throw StateError('BloomDevServer: Could not bind to any port between $preferredPort and ${preferredPort + 50}');
    }

    _server!.listen(_handleRequest);

    // Start mDNS / UDP Discovery
    _mdns = MdnsDiscovery();
    await _mdns!.startBroadcasting(
      projectName: project.projectName,
      devPort: _actualPort,
      localIp: _localIp,
    );
  }

  void _handleRequest(HttpRequest request) async {
    // Add CORS headers for mobile browser / Go inspector
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (path == '/manifest.json') {
      final routes = project.scanRoutes();
      final config = project.loadBloomConfig();
      final manifest = {
        'project': project.projectName,
        'version': config['version'] ?? '0.1.0',
        'host': _localIp,
        'port': _actualPort,
        'devServerUri': devServerUri,
        'routes': routes.map((r) => {'path': r.routePath, 'file': r.relativeFilePath}).toList(),
        'platforms': config['platforms'] ?? {},
        'features': config['features'] ?? {},
        'pairedDevicesCount': _pairedDevices.length,
      };

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(manifest));
    } else if (path == '/health') {
      final uptimeSeconds = DateTime.now().difference(_startedAt).inSeconds;
      final health = {
        'status': 'ok',
        'uptimeSeconds': uptimeSeconds,
        'project': project.projectName,
        'localIp': _localIp,
        'port': _actualPort,
        'hotReloadActive': true,
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(health));
    } else if (path == '/qr') {
      final qrText = QrTerminalRenderer.render(devServerUri);
      request.response.headers.contentType = ContentType.text;
      request.response.write(qrText);
    } else if (path == '/devices/pair' && request.method == 'POST') {
      try {
        final bodyStr = await utf8.decodeStream(request);
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        final device = {
          'id': body['id'] ?? 'device_${DateTime.now().millisecondsSinceEpoch}',
          'name': body['name'] ?? 'Mobile Device',
          'os': body['os'] ?? 'Unknown',
          'model': body['model'] ?? 'Wireless Client',
          'pairedAt': DateTime.now().toIso8601String(),
        };
        _pairedDevices.removeWhere((d) => d['id'] == device['id']);
        _pairedDevices.add(device);
        print('\n${Ansi.success('📱 Bloom Go Device Paired: ${device['name']} (${device['os']})')}\n');

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'status': 'paired', 'device': device}));
      } catch (e) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({'error': e.toString()}));
      }
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not Found');
    }

    await request.response.close();
  }

  /// Stop development server and discovery beacons.
  Future<void> stop() async {
    _mdns?.stop();
    await _server?.close(force: true);
    _server = null;
  }
}
