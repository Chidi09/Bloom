// lib/src/dev/mdns_discovery.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../utils/ansi.dart';

/// Discovers local network LAN IPv4 addresses and advertises development service beacons on the local subnet.
class MdnsDiscovery {
  static const int broadcastPort = 5354;
  RawDatagramSocket? _socket;
  Timer? _beaconTimer;

  /// Find preferred local network IPv4 address (Wi-Fi or Ethernet).
  static Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (!ip.startsWith('127.') && !ip.startsWith('169.254.')) {
            return ip;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  /// Start broadcasting Bloom Go discovery beacons over UDP multicast.
  Future<void> startBroadcasting({
    required String projectName,
    required int devPort,
    required String localIp,
  }) async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.broadcastEnabled = true;

      final beaconData = utf8.encode(jsonEncode({
        'service': 'bloom_dev_server',
        'version': '1.0.0',
        'project': projectName,
        'ip': localIp,
        'port': devPort,
        'uri': 'bloom://dev-server?host=$localIp&port=$devPort&id=$projectName',
      }));

      // Broadcast beacon every 2.5 seconds
      _beaconTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        try {
          _socket?.send(beaconData, InternetAddress('255.255.255.255'), broadcastPort);
        } catch (_) {}
      });
    } catch (e) {
      print(Ansi.warn('MdnsDiscovery: Unable to bind UDP broadcast socket: $e'));
    }
  }

  /// Stop discovery beacon broadcaster.
  void stop() {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _socket?.close();
    _socket = null;
  }
}
