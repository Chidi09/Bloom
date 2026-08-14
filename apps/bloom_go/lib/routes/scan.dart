// lib/routes/scan.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanRoute extends StatefulWidget {
  const ScanRoute({super.key});

  @override
  State<ScanRoute> createState() => _ScanRouteState();
}

class _ScanRouteState extends State<ScanRoute> {
  final TextEditingController _uriController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _uriController.dispose();
    super.dispose();
  }

  void _processScannedUri(String rawUri) {
    if (_isProcessing || rawUri.trim().isEmpty) return;
    _isProcessing = true;

    try {
      final uri = Uri.parse(rawUri.trim());
      BloomGoClient.parseDevServerUri(uri);
      final encoded = Uri.encodeComponent(rawUri.trim());
      BloomRouter.go('/session?uri=$encoded');
    } catch (e) {
      _isProcessing = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid Bloom URI: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Terminal QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            tooltip: 'Toggle Flashlight',
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            tooltip: 'Switch Camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Real Mobile Camera QR Viewfinder
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        _processScannedUri(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
                // Scanning Target Overlay
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.deepPurpleAccent, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Point camera at the QR code displayed in your terminal',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Manual URI Input Fallback
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
