// lib/routes/index.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class IndexRoute extends StatefulWidget {
  const IndexRoute({super.key});

  @override
  State<IndexRoute> createState() => _IndexRouteState();
}

class _IndexRouteState extends State<IndexRoute> {
  final TextEditingController _ipController = TextEditingController();
  final BloomDiscoveryListener _discovery = BloomDiscoveryListener();
  final List<BloomDiscoveredServer> _discoveredServers = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _discovery.startListening();
    _sub = _discovery.discoveredServers.listen((server) {
      if (!mounted) return;
      setState(() {
        _discoveredServers.removeWhere((s) => s.uri == server.uri);
        _discoveredServers.add(server);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _discovery.stop();
    _ipController.dispose();
    super.dispose();
  }

  void _connectTo(String uriStr) {
    final encoded = Uri.encodeComponent(uriStr);
    BloomRouter.go('/session?uri=$encoded');
  }

  void _connectManual() {
    final input = _ipController.text.trim();
    if (input.isEmpty) return;

    final parts = input.split(':');
    final host = parts[0];
    final port = parts.length > 1 ? parts[1] : '8080';
    final devUri = 'bloom://dev-server?host=$host&port=$port&id=manual_project';
    _connectTo(devUri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_florist_rounded, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('Bloom Go', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan QR Code',
            onPressed: () => BloomRouter.go('/scan'),
          ),
        ],
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hero Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instant Mobile Development',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scan the QR code in your terminal or select a detected project below.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => BloomRouter.go('/scan'),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan Terminal QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Discovered Projects on Wi-Fi
          Row(
            children: [
              const Icon(Icons.wifi_tethering_rounded, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Discovered on Local Wi-Fi (${_discoveredServers.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_discoveredServers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Scanning local subnet for active Bloom dev servers...\nMake sure `bloom dev` is running on your machine.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._discoveredServers.map((server) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: Icon(Icons.code_rounded, color: Colors.white),
                  ),
                  title: Text(server.projectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${server.ip}:${server.port}'),
                  trailing: ElevatedButton(
                    onPressed: () => _connectTo(server.uri),
                    child: const Text('Open'),
                  ),
                ),
              );
            }),

          const SizedBox(height: 28),

          // Manual IP Connect
          Row(
            children: [
              const Icon(Icons.lan_rounded, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Manual Host & Port Connect',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    hintText: '192.168.1.50:8080',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _connectManual,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Connect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
