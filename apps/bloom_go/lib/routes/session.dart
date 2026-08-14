// lib/routes/session.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class SessionRoute extends StatefulWidget {
  final String? uriString;

  const SessionRoute({super.key, this.uriString});

  @override
  State<SessionRoute> createState() => _SessionRouteState();
}

class _SessionRouteState extends State<SessionRoute> {
  final BloomGoClient _client = BloomGoClient();
  BloomProjectManifest? _manifest;
  bool _isLoading = true;
  String? _error;
  String _httpBaseUrl = '';
  String _projectId = '';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rawUri = widget.uriString ?? '';
      if (rawUri.isEmpty) {
        throw const FormatException('No dev server URI provided in query parameters.');
      }

      final uri = Uri.parse(Uri.decodeComponent(rawUri));
      final parsed = BloomGoClient.parseDevServerUri(uri);
      _httpBaseUrl = parsed['httpBaseUrl'] as String;
      _projectId = parsed['projectId'] as String;

      // 1. Fetch project manifest
      final manifest = await _client.fetchManifest(_httpBaseUrl);

      // 2. Register mobile device pairing
      await _client.registerDevice(
        httpBaseUrl: _httpBaseUrl,
        deviceName: 'Bloom Go Mobile Client',
        os: 'Flutter Native Runtime',
      );

      if (mounted) {
        setState(() {
          _manifest = manifest;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_manifest?.projectName ?? 'Connecting to $_projectId...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Open Bloom Dev Inspector',
            onPressed: () => BloomDevOverlay.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Manifest',
            onPressed: _connect,
          ),
        ],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 16),
                  Text('Connecting to Bloom Dev Server...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text('Connection Failed', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _connect,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => BloomRouter.go('/'),
                          child: const Text('Back to Hub'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Connected Status Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Connected to ${_manifest!.projectName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Host: $_httpBaseUrl (v${_manifest!.version})',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Active Routes Section
                    Text(
                      'Available Routes (${_manifest!.routes.length})',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ..._manifest!.routes.map((r) {
                      final path = r['path']?.toString() ?? '/';
                      final file = r['file']?.toString() ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: const Icon(Icons.alt_route_rounded, color: Colors.deepPurple),
                          title: Text(path, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(file),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),

                    // Quick Actions
                    ElevatedButton.icon(
                      onPressed: () => BloomDevOverlay.show(context),
                      icon: const Icon(Icons.developer_mode_rounded),
                      label: const Text('Open Bloom Dev Overlay'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => BloomRouter.go('/'),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Disconnect & Return to Hub'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
    );
  }
}
