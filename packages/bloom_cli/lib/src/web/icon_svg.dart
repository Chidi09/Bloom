// lib/src/web/icon_svg.dart

/// Generates the canonical Bloom brand mark (five-petal gradient flower + white sparkle) as an SVG string.
///
/// Designed on a 200x200 grid matching `BloomLogo` in `bloom_framework`.
String buildBloomLogoSvg({
  bool isMaskable = false,
  bool hasOpaqueBackground = false,
  String themeColor = '#6200EE',
}) {
  final buffer = StringBuffer();
  buffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="100%" height="100%">');
  buffer.writeln('  <defs>');
  buffer.writeln('    <linearGradient id="petal1" gradientUnits="userSpaceOnUse" x1="100" y1="20" x2="100" y2="100">');
  buffer.writeln('      <stop offset="0%" stop-color="#FF4B8B" />');
  buffer.writeln('      <stop offset="100%" stop-color="#FF8BA7" />');
  buffer.writeln('    </linearGradient>');
  buffer.writeln('    <linearGradient id="petal2" gradientUnits="userSpaceOnUse" x1="180" y1="80" x2="110" y2="110">');
  buffer.writeln('      <stop offset="0%" stop-color="#FF884D" />');
  buffer.writeln('      <stop offset="100%" stop-color="#FFA066" />');
  buffer.writeln('    </linearGradient>');
  buffer.writeln('    <linearGradient id="petal3" gradientUnits="userSpaceOnUse" x1="140" y1="175" x2="100" y2="115">');
  buffer.writeln('      <stop offset="0%" stop-color="#20C9B0" />');
  buffer.writeln('      <stop offset="100%" stop-color="#48E5C8" />');
  buffer.writeln('    </linearGradient>');
  buffer.writeln('    <linearGradient id="petal4" gradientUnits="userSpaceOnUse" x1="60" y1="175" x2="100" y2="115">');
  buffer.writeln('      <stop offset="0%" stop-color="#2563EB" />');
  buffer.writeln('      <stop offset="100%" stop-color="#60A5FA" />');
  buffer.writeln('    </linearGradient>');
  buffer.writeln('    <linearGradient id="petal5" gradientUnits="userSpaceOnUse" x1="20" y1="80" x2="90" y2="110">');
  buffer.writeln('      <stop offset="0%" stop-color="#8B5CF6" />');
  buffer.writeln('      <stop offset="100%" stop-color="#A855F7" />');
  buffer.writeln('    </linearGradient>');
  buffer.writeln('  </defs>');

  if (isMaskable || hasOpaqueBackground) {
    buffer.writeln('  <rect width="200" height="200" fill="$themeColor" />');
  }

  if (isMaskable) {
    // Safe-zone padding for adaptive icons (80% scale, 10% padding on each side)
    buffer.writeln('  <g transform="translate(20, 20) scale(0.8)">');
  }

  buffer.writeln('    <path d="M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z" fill="url(#petal1)" fill-opacity="0.95" />');
  buffer.writeln('    <path d="M180 80 C190 110 155 135 125 115 C115 100 105 85 115 70 C145 50 170 50 180 80 Z" fill="url(#petal2)" fill-opacity="0.95" />');
  buffer.writeln('    <path d="M140 175 C115 185 85 155 100 125 C110 110 125 105 135 115 C165 135 165 165 140 175 Z" fill="url(#petal3)" fill-opacity="0.95" />');
  buffer.writeln('    <path d="M60 175 C35 165 35 135 65 115 C75 105 90 110 100 125 C115 155 85 185 60 175 Z" fill="url(#petal4)" fill-opacity="0.95" />');
  buffer.writeln('    <path d="M20 80 C30 50 55 50 85 70 C95 85 85 100 75 115 C45 135 10 110 20 80 Z" fill="url(#petal5)" fill-opacity="0.95" />');
  buffer.writeln('    <path d="M100 82 L104 96 L118 100 L104 104 L100 118 L96 104 L82 100 L96 96 Z" fill="#FFFFFF" />');

  if (isMaskable) {
    buffer.writeln('  </g>');
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}
