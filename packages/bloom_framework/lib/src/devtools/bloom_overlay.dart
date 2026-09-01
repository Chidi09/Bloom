/// In-app developer diagnostics overlay and query cache inspector.
library;

import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:bloom_ui/bloom_ui.dart' as ui;
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
///   child: const ui.BloomIcon(ui.BloomIcons.developerMode),
/// );
/// ```
class BloomDevOverlay extends StatefulWidget {
  /// Optional base URL of remote Bloom dev server when inspecting paired devices.
  final String? remoteBaseUrl;

  /// Creates a [BloomDevOverlay] widget.
  const BloomDevOverlay({super.key, this.remoteBaseUrl});

  /// Shows the Bloom developer bottom sheet modal with optional remote dev server inspection.
  static Future<void> show(BuildContext context, {String? remoteBaseUrl}) {
    return ui.showBloomSheet(
      context: context,
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
    final colors = context.bloomColors;
    final typography = context.bloomTypography;
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
        color: colors.surface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Color(0x42000000), blurRadius: 20, spreadRadius: 4),
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
              color: const Color(0xFFBDBDBD),
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
                  style: TextStyle(
                    fontFamily: typography.sans,
                    fontSize: typography.xl,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                ui.BloomIconButton(
                  icon: const ui.BloomIcon(ui.BloomIcons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const ui.BloomSeparator(thickness: 1.0, margin: EdgeInsets.zero),
          // Content Tabs
          Expanded(
            child: _isLoadingRemote
                ? const Center(child: ui.BloomSpinner(color: Color(0xFF673AB7)))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ui.BloomTabs<String>(
                      defaultValue: 'app_info',
                      items: [
                        ui.BloomTabItem<String>(
                          value: 'app_info',
                          label: const Text('App Info'),
                          icon: const ui.BloomIcon(ui.BloomIcons.infoOutline),
                          content: Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                                ui.BloomButton(
                                  variant: ui.BloomButtonVariant.destructive,
                                  onPressed: () {
                                    BloomData.clear();
                                    ui.BloomToastHost.show(
                                      context,
                                      child: const Text('Query cache purged successfully'),
                                    );
                                  },
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ui.BloomIcon(
                                        ui.BloomIcons.deleteOutline,
                                        color: Color(0xFFFFFFFF),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Purge Query Cache',
                                        style: TextStyle(color: Color(0xFFFFFFFF)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ui.BloomTabItem<String>(
                          value: 'cache',
                          label: const Text('Cache'),
                          icon: const ui.BloomIcon(ui.BloomIcons.storage),
                          content: Expanded(
                            child: cacheEntries.isEmpty
                                ? const Center(child: Text('No active cache entries'))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: cacheEntries.length,
                                    itemBuilder: (context, index) {
                                      final entry = cacheEntries[index];
                                      final isExpired = entry['isExpired'] as bool;
                                      final isStale = entry['isStale'] as bool;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: ui.BloomCard(
                                          child: ui.BloomItem(
                                            title: Text(
                                              entry['key'].toString(),
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            description: Text('Updated: ${entry['updatedAt']}'),
                                            actions: Container(
                                              decoration: BoxDecoration(
                                                color: isExpired
                                                    ? const Color(0xFFFFCDD2)
                                                    : (isStale ? const Color(0xFFFFECB3) : const Color(0xFFC8E6C9)),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: ui.BloomBadge(
                                                variant: ui.BloomBadgeVariant.ghost,
                                                child: Text(
                                                  isExpired ? 'Expired' : (isStale ? 'Stale' : 'Fresh'),
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        ui.BloomTabItem<String>(
                          value: 'environment',
                          label: const Text('Environment'),
                          icon: const ui.BloomIcon(ui.BloomIcons.tune),
                          content: Expanded(
                            child: envEntries.isEmpty
                                ? const Center(child: Text('No environment variables loaded'))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: envEntries.length,
                                    itemBuilder: (context, index) {
                                      final entry = envEntries[index];
                                      return ui.BloomItem(
                                        title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        description: Text(entry.value),
                                      );
                                    },
                                  ),
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
          Text(label, style: const TextStyle(color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
