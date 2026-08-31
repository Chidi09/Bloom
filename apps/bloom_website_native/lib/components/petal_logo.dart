import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode petalLogo({
  String highlight = 'all',
  double size = 40,
  String className =
      'transform group-hover:rotate-12 transition duration-700 ease-in-out',
}) {
  double getOpacity(String petalColor) {
    if (highlight == 'all') return 0.95;
    return highlight == petalColor ? 1.0 : 0.35;
  }

  final sizePx = '${size}px';
  final oPink = getOpacity('pink');
  final oOrange = getOpacity('orange');
  final oCyan = getOpacity('cyan');
  final oBlue = getOpacity('blue');
  final oPurple = getOpacity('purple');

  final svgString =
      '''
<div class="relative flex items-center justify-center shrink-0" style="width: $sizePx; height: $sizePx;">
  <svg class="w-full h-full $className" viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z" fill="url(#p_pink)" opacity="$oPink" />
    <path d="M180 80 C190 110 155 135 125 115 C115 100 105 85 115 70 C145 50 170 50 180 80 Z" fill="url(#p_orange)" opacity="$oOrange" />
    <path d="M140 175 C115 185 85 155 100 125 C110 110 125 105 135 115 C165 135 165 165 140 175 Z" fill="url(#p_cyan)" opacity="$oCyan" />
    <path d="M60 175 C35 165 35 135 65 115 C75 105 90 110 100 125 C115 155 85 185 60 175 Z" fill="url(#p_blue)" opacity="$oBlue" />
    <path d="M20 80 C30 50 55 50 85 70 C95 85 85 100 75 115 C45 135 10 110 20 80 Z" fill="url(#p_purple)" opacity="$oPurple" />
    <path d="M100 82 L104 96 L118 100 L104 104 L100 118 L96 104 L82 100 L96 96 Z" fill="#FFFFFF" class="drop-shadow-md"/>
    <defs>
      <linearGradient id="p_pink" x1="100" y1="20" x2="100" y2="100"><stop stop-color="#FF4B8B"/><stop offset="1" stop-color="#FF8BA7"/></linearGradient>
      <linearGradient id="p_orange" x1="180" y1="80" x2="110" y2="110"><stop stop-color="#FF884D"/><stop offset="1" stop-color="#FFA066"/></linearGradient>
      <linearGradient id="p_cyan" x1="140" y1="175" x2="100" y2="115"><stop stop-color="#20C9B0"/><stop offset="1" stop-color="#48E5C8"/></linearGradient>
      <linearGradient id="p_blue" x1="60" y1="175" x2="100" y2="115"><stop stop-color="#2563EB"/><stop offset="1" stop-color="#60A5FA"/></linearGradient>
      <linearGradient id="p_purple" x1="20" y1="80" x2="90" y2="110"><stop stop-color="#8B5CF6"/><stop offset="1" stop-color="#A855F7"/></linearGradient>
    </defs>
  </svg>
</div>
''';

  return Raw(svgString);
}
