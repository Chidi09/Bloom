// lib/src/dev/qr_renderer.dart
import 'package:qr/qr.dart';

/// Renders QR codes directly into ANSI terminal text using Unicode half-block characters.
/// Uses standard black foreground on white background to produce an accurate positive QR code.
class QrTerminalRenderer {
  /// Render [data] string into a multi-line ANSI terminal QR code.
  static String render(String data, {int errorCorrectLevel = QrErrorCorrectLevel.M}) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: errorCorrectLevel,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;

    final buffer = StringBuffer();

    // Border quiet zone (2 modules light/white border)
    const quietZone = 2;
    final totalSize = moduleCount + quietZone * 2;

    // Helper to get module (true = dark/black, false = light/white)
    bool isDark(int x, int y) {
      final imgX = x - quietZone;
      final imgY = y - quietZone;
      if (imgX < 0 || imgX >= moduleCount || imgY < 0 || imgY >= moduleCount) {
        return false; // Quiet zone is white/light
      }
      return qrImage.isDark(imgY, imgX);
    }

    // ANSI White background with Black foreground
    const whiteBg = '\x1B[47m';
    const blackFg = '\x1B[30m';
    const reset = '\x1B[0m';

    // Group rows in pairs:
    // Upper pixel uses foreground black; lower pixel uses background white.
    for (int y = 0; y < totalSize; y += 2) {
      buffer.write('$whiteBg$blackFg');
      for (int x = 0; x < totalSize; x++) {
        final topDark = isDark(x, y);
        final bottomDark = (y + 1 < totalSize) ? isDark(x, y + 1) : false;

        if (topDark && bottomDark) {
          buffer.write('█'); // Both pixels dark (black foreground on white bg)
        } else if (topDark && !bottomDark) {
          buffer.write('▀'); // Top pixel dark, bottom light (upper half block)
        } else if (!topDark && bottomDark) {
          buffer.write('▄'); // Top pixel light, bottom dark (lower half block)
        } else {
          buffer.write(' '); // Both pixels light (white background)
        }
      }
      buffer.writeln(reset);
    }

    return buffer.toString();
  }
}
