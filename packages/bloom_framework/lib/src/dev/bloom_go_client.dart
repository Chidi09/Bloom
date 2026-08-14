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
      projectName: json['project']?.toString() ?? json['appName']?.toString() ?? 'bloom_app',
      version: json['version']?.toString() ?? '0.1.0',
      host: json['host']?.toString() ?? json['ip']?.toString() ?? '127.0.0.1',
      port: json['port'] is int ? json['port'] as int : int.tryParse(json['port']?.toString() ?? '') ?? 8080,
      devServerUri: json['devServerUri']?.toString() ?? json['uri']?.toString() ?? '',
      routes: json['routes'] is List ? List<Map<String, dynamic>>.from(json['routes'] as List) : [],
      platforms: json['platforms'] is Map ? Map<String, dynamic>.from(json['platforms'] as Map) : {},
      features: json['features'] is Map ? Map<String, dynamic>.from(json['features'] as Map) : {},
    );
  }
}

class BloomDiscoveredServer {
  final String name;
  final String host;
  final int port;
  final String version;
  final String projectId;
  final String appName;
  final DateTime lastSeen;

  BloomDiscoveredServer({
    String? name,
    String? host,
    String? ip,
    int? port,
    String? version,
    String? projectId,
    String? projectName,
    String? appName,
    String? uri,
    DateTime? lastSeen,
    DateTime? discoveredAt,
  })  : name = name ?? projectName ?? appName ?? 'Bloom Dev Server',
        host = host ?? ip ?? '127.0.0.1',
        port = port ?? 4040,
        version = version ?? '0.1.0',
        projectId = projectId ?? projectName ?? 'bloom_app',
        appName = appName ?? name ?? 'Bloom App',
        lastSeen = lastSeen ?? discoveredAt ?? DateTime.now();

  String get ip => host;
  String get projectName => projectId;
  String get uri => 'http://$host:$port';
  String get endpoint => uri;
  DateTime get discoveredAt => lastSeen;

  Map<String, dynamic> toJson() => {
        'name': name,
        'host': host,
        'port': port,
        'version': version,
        'projectId': projectId,
        'appName': appName,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory BloomDiscoveredServer.fromJson(Map<String, dynamic> json, {String? defaultHost}) {
    return BloomDiscoveredServer(
      name: json['name']?.toString() ?? json['project']?.toString() ?? 'Bloom Dev Server',
      host: json['host']?.toString() ?? json['ip']?.toString() ?? defaultHost ?? '127.0.0.1',
      port: json['port'] is int ? json['port'] as int : int.tryParse(json['port']?.toString() ?? '') ?? 4040,
      version: json['version']?.toString() ?? '0.1.0',
      projectId: json['projectId']?.toString() ?? json['project']?.toString() ?? 'bloom_app',
      appName: json['appName']?.toString() ?? json['name']?.toString() ?? 'Bloom App',
      lastSeen: DateTime.now(),
    );
  }
}

/// UDP discovery service for scanning LAN networks for active Bloom Dev Servers on port 5354.
class BloomDevServerDiscovery {
  static const int udpPort = 5354;

  final Map<String, BloomDiscoveredServer> _servers = {};
  RawDatagramSocket? _socket;
  StreamController<List<BloomDiscoveredServer>>? _controller;

  /// Starts listening for UDP broadcast announcements and returns a stream of discovered servers.
  Stream<List<BloomDiscoveredServer>> discover({RawDatagramSocket? customSocket}) {
    _controller = StreamController<List<BloomDiscoveredServer>>.broadcast(
      onCancel: stop,
    );

    if (customSocket != null) {
      _listenToSocket(customSocket);
    } else {
      try {
        RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort, reuseAddress: true, reusePort: true)
            .then((socket) {
          _socket = socket;
          _socket?.broadcastEnabled = true;
          _listenToSocket(socket);
        }).catchError((e) {
          logger.warn('BloomDevServerDiscovery: Failed to bind UDP port $udpPort: $e');
        });
      } catch (e) {
        logger.warn('BloomDevServerDiscovery: UDP binding exception: $e');
      }
    }

    return _controller!.stream;
  }

  void _listenToSocket(RawDatagramSocket socket) {
    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          try {
            final text = utf8.decode(datagram.data);
            final json = jsonDecode(text);
            if (json is Map<String, dynamic> &&
                (json['type'] == 'bloom_dev_server' || json['service'] == 'bloom_dev_server')) {
              final server = BloomDiscoveredServer.fromJson(
                json,
                defaultHost: datagram.address.address,
              );
              final key = '${server.host}:${server.port}';
              _servers[key] = server;
              _controller?.add(List.unmodifiable(_servers.values.toList()));
            }
          } catch (_) {}
        }
      }
    });
  }

  /// Manually ingest a discovered server payload (ideal for tests or direct pairing).
  void ingestServer(BloomDiscoveredServer server) {
    final key = '${server.host}:${server.port}';
    _servers[key] = server;
    _controller?.add(List.unmodifiable(_servers.values.toList()));
  }

  /// Broadcasts an announcement packet from a dev server.
  static Future<void> broadcastAnnouncement({
    required String name,
    required String host,
    required int port,
    required String projectId,
    required String appName,
    String version = '0.1.0',
    RawDatagramSocket? customSocket,
  }) async {
    final payload = jsonEncode({
      'type': 'bloom_dev_server',
      'service': 'bloom_dev_server',
      'name': name,
      'project': projectId,
      'host': host,
      'ip': host,
      'port': port,
      'projectId': projectId,
      'appName': appName,
      'version': version,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final bytes = utf8.encode(payload);

    if (customSocket != null) {
      customSocket.send(bytes, InternetAddress('255.255.255.255'), udpPort);
    } else {
      try {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        socket.broadcastEnabled = true;
        socket.send(bytes, InternetAddress('255.255.255.255'), udpPort);
        socket.close();
      } catch (_) {}
    }
  }

  /// Stops discovery listener and releases network socket.
  void stop() {
    _socket?.close();
    _socket = null;
    _controller?.close();
    _controller = null;
  }
}

/// Alias for backwards compatibility with Bloom Go discovery listener.
typedef BloomDiscoveryListener = BloomDevServerDiscovery;

/// Client protocol handler for Bloom Go mobile applications.
class BloomGoClient {
  final http.Client _httpClient;

  BloomGoClient([http.Client? httpClient]) : _httpClient = httpClient ?? http.Client();

  /// Parse a `bloom://dev-server?...` QR code URI.
  static Map<String, dynamic> parseDevServerUri(Uri uri) {
    if (uri.scheme != 'bloom') {
      throw FormatException('Invalid scheme "${uri.scheme}", expected "bloom".');
    }

    final query = uri.queryParameters;
    final host = query['host'];
    if (host == null || host.isEmpty) {
      throw FormatException('Invalid or missing host in dev server URI: $uri');
    }
    final port = int.tryParse(query['port'] ?? '') ?? 8080;
    final projectId = query['id'] ?? query['project'] ?? 'unknown';

    return {
      'host': host,
      'port': port,
      'projectId': projectId,
      'project': projectId,
      'version': query['v'] ?? '0.1.0',
      'httpBaseUrl': 'http://$host:$port',
    };
  }

  /// Fetch the remote project manifest from an active Bloom dev server.
  Future<BloomProjectManifest> fetchManifest(String host, int port) async {
    final url = Uri.parse('http://$host:$port/manifest');
    final response = await _httpClient.get(url).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return BloomProjectManifest.fromJson(json);
    } else {
      throw HttpException('Failed to fetch manifest: HTTP ${response.statusCode}');
    }
  }

  /// Send device pairing handshake to dev server.
  Future<bool> pairDevice({
    required String host,
    required int port,
    required String deviceName,
    required String platform,
  }) async {
    final url = Uri.parse('http://$host:$port/devices/pair');
    final response = await _httpClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': deviceName,
        'platform': platform,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 5));

    return response.statusCode == 200;
  }

  void close() {
    _httpClient.close();
  }
}
