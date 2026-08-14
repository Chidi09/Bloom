// lib/routes/scan.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class ScanRoute extends StatefulWidget {
  const ScanRoute({super.key});

  @override
  State<ScanRoute> createState() => _ScanRouteState();
}

class _ScanRouteState extends State<ScanRoute> {
  final TextEditingController _uriController = TextEditingController();

  @override
  void dispose() {
    _uriController.dispose();
    super.dispose();
  }

  void _processScannedUri(String rawUri) {
    if (rawUri.trim().isEmpty) return;

    try {
      final uri = Uri.parse(rawUri.trim());
      BloomGoClient.parseDevServerUri(uri);
      final encoded = Uri.encodeComponent(rawUri.trim());
      BloomRouter.go('/session?uri=$encoded');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid Bloom URI: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Terminal QR'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Viewfinder simulation / camera viewfinder box
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.deepPurpleAccent, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 96,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Point camera at the QR code displayed by `bloom dev`',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Manual URI Input Bar
          Container(
            padding: const EdgeInsets.all(20),
            color: theme.colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Or enter pairing URI manually:', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _uriController,
                        decoration: InputDecoration(
                          hintText: 'bloom://dev-server?host=192.168.1.50&port=8080&id=app',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _processScannedUri(_uriController.text),
                      child: const Text('Open'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
