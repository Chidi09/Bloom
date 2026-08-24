/// In-app developer diagnostics overlay and query cache inspector.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/boot.dart';
import '../core/env.dart';
import '../data/cache.dart';
import '../widgets/bloom_logo.dart';

/// Universal in-app developer modal and diagnostics overlay for Bloom applications and Bloom Go.
///
/// Provides live inspection of configuration, query cache entries, and environment variables.
///
/// Example:
/// ```dart
/// FloatingActionButton(
///   onPressed: () => BloomDevOverlay.show(context),
///   child: const Icon(Icons.developer_mode),
/// );
/// ```
class BloomDevOverlay extends StatefulWidget {
  /// Optional base URL of remote Bloom dev server when inspecting paired devices.
  final String? remoteBaseUrl;

  /// Creates a [BloomDevOverlay] widget.
  const BloomDevOverlay({super.key, this.remoteBaseUrl});

  /// Shows the Bloom developer bottom sheet modal with optional remote dev server inspection.
  static Future<void> show(BuildContext context, {String? remoteBaseUrl}) {

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BloomDevOverlay(remoteBaseUrl: remoteBaseUrl),
    );
  }

  @override
  State<BloomDevOverlay> createState() => _BloomDevOverlayState();
}

class _BloomDevOverlayState extends State<BloomDevOverlay> {
  Map<String, dynamic>? _remoteConfig;
  Map<String, String>? _remoteEnv;
  bool _isLoadingRemote = false;

  @override
  void initState() {
    super.initState();
    if (widget.remoteBaseUrl != null) {
      _loadRemoteDiagnostics();
    }
  }

  Future<void> _loadRemoteDiagnostics() async {
    setState(() => _isLoadingRemote = true);
    try {
      final configRes = await http.get(Uri.parse('${widget.remoteBaseUrl}/inspect/config'));
      final envRes = await http.get(Uri.parse('${widget.remoteBaseUrl}/inspect/env'));

      if (mounted) {
        setState(() {
          if (configRes.statusCode == 200) {
            _remoteConfig = jsonDecode(configRes.body) as Map<String, dynamic>;
          }
          if (envRes.statusCode == 200) {
            _remoteEnv = Map<String, String>.from(jsonDecode(envRes.body) as Map);
          }
          _isLoadingRemote = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRemote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRemote = widget.remoteBaseUrl != null;

    final projectName = _remoteConfig?['name']?.toString() ?? Bloom.config.name;
    final projectVersion = _remoteConfig?['version']?.toString() ?? Bloom.config.version;
    final projectMode = _remoteConfig?['mode']?.toString() ?? Bloom.config.mode;

    final cacheEntries = BloomData.dumpCache();
    final envEntries = _remoteEnv != null
        ? _remoteEnv!.entries.toList()
        : BloomEnv.all.entries.toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 4),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const BloomLogo(size: 28),
                const SizedBox(width: 10),
                Text(
                  isRemote ? 'Connected: $projectName' : 'Bloom Dev Inspector',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content Tabs
          Expanded(
            child: _isLoadingRemote
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                : DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: Colors.deepPurple,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.deepPurple,
                          tabs: [
                            Tab(icon: Icon(Icons.info_outline), text: 'App Info'),
                            Tab(icon: Icon(Icons.storage_rounded), text: 'Cache'),
                            Tab(icon: Icon(Icons.tune_rounded), text: 'Environment'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab 1: App Info
                              ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  _buildInfoTile('Target App', projectName),
                                  _buildInfoTile('Version', projectVersion),
                                  _buildInfoTile('Mode', projectMode),
                                  if (isRemote)
                                    _buildInfoTile('Host URL', widget.remoteBaseUrl!)
                                  else
                                    _buildInfoTile('Active Flavor', Bloom.activeFlavor ?? 'None (Default)'),
                                  _buildInfoTile('Active Cache Entries', '${BloomData.entryCount}'),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      BloomData.clear();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Query cache purged successfully')),
                                      );
                                    },
                                    icon: const Icon(Icons.delete_sweep_rounded),
                                    label: const Text('Purge Query Cache'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              // Tab 2: Cache Entries
                              cacheEntries.isEmpty
                                  ? const Center(child: Text('No active cache entries'))
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: cacheEntries.length,
                                      itemBuilder: (context, index) {
                                        final entry = cacheEntries[index];
                                        final isExpired = entry['isExpired'] as bool;
                                        final isStale = entry['isStale'] as bool;

                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                            title: Text(
                                              entry['key'].toString(),
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            subtitle: Text('Updated: ${entry['updatedAt']}'),
                                            trailing: Chip(
                                              label: Text(
                                                isExpired ? 'Expired' : (isStale ? 'Stale' : 'Fresh'),
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              backgroundColor: isExpired
                                                  ? Colors.red.shade100
                                                  : (isStale ? Colors.amber.shade100 : Colors.green.shade100),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                              // Tab 3: Environment Variables
                              envEntries.isEmpty
                                  ? const Center(child: Text('No environment variables loaded'))
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: envEntries.length,
                                      itemBuilder: (context, index) {
                                        final entry = envEntries[index];
                                        return ListTile(
                                          dense: true,
                                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text(entry.value),
                                        );
                                      },
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
