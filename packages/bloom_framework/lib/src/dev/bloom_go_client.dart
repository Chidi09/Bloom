// lib/src/dev/bloom_go_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/logger.dart';

class BloomProjectManifest {
  final String projectName;
  final String version;
  final String host;
  final int port;
  final String devServerUri;
  final List<Map<String, dynamic>> routes;
  final Map<String, dynamic> platforms;
  final Map<String, dynamic> features;

  const BloomProjectManifest({
    required this.projectName,
    required this.version,
    required this.host,
    required this.port,
    required this.devServerUri,
    required this.routes,
    required this.platforms,
    required this.features,
  });

  factory BloomProjectManifest.fromJson(Map<String, dynamic> json) {
    return BloomProjectManifest(
      projectName: json['project']?.toString() ?? 'bloom_app',
      version: json['version']?.toString() ?? '0.1.0',
      host: json['host']?.toString() ?? '127.0.0.1',
      port: json['port'] is int ? json['port'] as int : 8080,
      devServerUri: json['devServerUri']?.toString() ?? '',
      routes: json['routes'] is List ? List<Map<String, dynamic>>.from(json['routes'] as List) : [],
      platforms: json['platforms'] is Map ? Map<String, dynamic>.from(json['platforms'] as Map) : {},
      features: json['features'] is Map ? Map<String, dynamic>.from(json['features'] as Map) : {},
    );
  }
}

class BloomDiscoveredServer {
  final String projectName;
  final String ip;
  final int port;
  final String uri;
  final DateTime discoveredAt;

  BloomDiscoveredServer({
    required this.projectName,
    required this.ip,
    required this.port,
    required this.uri,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();
}

/// UDP discovery listener that scans the local Wi-Fi subnet for active Bloom development servers.
class BloomDiscoveryListener {
  static const int broadcastPort = 5354;
  RawDatagramSocket? _socket;
  final StreamController<BloomDiscoveredServer> _controller =
      StreamController<BloomDiscoveredServer>.broadcast();

  Stream<BloomDiscoveredServer> get discoveredServers => _controller.stream;

  /// Start listening for broadcast discovery beacons on the local network.
  Future<void> startListening() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        broadcastPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket?.broadcastEnabled = true;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            try {
              final payload = utf8.decode(datagram.data);
              final json = jsonDecode(payload) as Map<String, dynamic>;
              if (json['service'] == 'bloom_dev_server') {
                final server = BloomDiscoveredServer(
                  projectName: json['project']?.toString() ?? 'unknown',
                  ip: json['ip']?.toString() ?? datagram.address.address,
                  port: json['port'] is int ? json['port'] as int : 8080,
                  uri: json['uri']?.toString() ?? '',
                );
                _controller.add(server);
              }
            } catch (_) {}
          }
        }
      });
      logger.info('BloomDiscoveryListener: Listening for Bloom Dev beacons on port $broadcastPort');
    } catch (e) {
      logger.warn('BloomDiscoveryListener: Could not bind discovery socket: $e');
    }
  }

  /// Stop listening for discovery beacons.
  void stop() {
    _socket?.close();
    _socket = null;
  }
}

/// Client protocol handler for Bloom Go mobile applications.
class BloomGoClient {
  final http.Client _httpClient;

  BloomGoClient([http.Client? httpClient]) : _httpClient = httpClient ?? http.Client();

  /// Parse a `bloom://dev-server?...` QR code URI.
  static Map<String, dynamic> parseDevServerUri(Uri uri) {
    if (uri.scheme != 'bloom') {
      throw FormatException('Invalid URI scheme. Expected "bloom://", got "${uri.scheme}://"');
    }

    final host = uri.queryParameters['host'] ?? uri.host;
    if (host.trim().isEmpty) {
      throw const FormatException('Invalid dev server URI: host cannot be empty.');
    }

    final portStr = uri.queryParameters['port'] ?? (uri.hasPort ? uri.port.toString() : '8080');
    final port = int.tryParse(portStr) ?? 8080;
    final projectId = uri.queryParameters['id'] ?? 'bloom_app';

    return {
      'host': host,
      'port': port,
      'projectId': projectId,
      'httpBaseUrl': 'http://$host:$port',
    };
  }

  /// Fetch application manifest from the active dev server with timeout.
  Future<BloomProjectManifest> fetchManifest(
    String httpBaseUrl, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    logger.info('BloomGoClient: Fetching project manifest from $httpBaseUrl/manifest.json...');
    final response = await _httpClient
        .get(Uri.parse('$httpBaseUrl/manifest.json'))
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw StateError('Failed to fetch manifest: HTTP ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return BloomProjectManifest.fromJson(decoded);
  }

  /// Register device pairing with the dev server with timeout.
  Future<bool> registerDevice({
    required String httpBaseUrl,
    required String deviceName,
    required String os,
    String model = 'Mobile Device',
    Duration timeout = const Duration(seconds: 5),
  }) async {
    logger.info('BloomGoClient: Registering device "$deviceName" with $httpBaseUrl...');
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$httpBaseUrl/devices/pair'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': deviceName,
              'os': os,
              'model': model,
            }),
          )
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (e) {
      logger.error('BloomGoClient: Failed to pair device: $e');
      return false;
    }
  }
}
