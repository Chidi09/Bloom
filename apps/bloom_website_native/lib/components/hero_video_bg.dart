import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode heroVideoBg({String mode = 'hub'}) {
  const videos = {
    'hub': '/videos/hub.mp4',
    'build': '/videos/build.mp4',
    'ship': '/videos/ship.mp4',
    'bloom': '/videos/bloom.mp4',
  };

  const imageBgs = {
    'ship': '/images/cloud-bg.jpg',
    'build': '/images/building-blocks.jpg',
    'bloom': '/gifs/liquid-studio.gif',
  };

  final videoSrc = videos[mode] ?? '/videos/hub.mp4';
  final videoClass = mode == 'hub'
      ? 'opacity-30 dark:opacity-35 mix-blend-screen filter saturate-120 contrast-125 scale-105'
      : 'opacity-10 dark:opacity-15 mix-blend-screen filter grayscale contrast-125 scale-105';

  String imgTag = '';
  if (mode == 'ship') {
    imgTag =
        '<img src="${imageBgs['ship']}" alt="Cloud Background" class="absolute inset-0 w-full h-full object-cover opacity-25 dark:opacity-30 filter grayscale contrast-130 brightness-90 scale-105 transition-opacity duration-700" />';
  } else if (mode == 'build') {
    imgTag =
        '<img src="${imageBgs['build']}" alt="Building Blocks Background" class="absolute inset-0 w-full h-full object-cover opacity-20 dark:opacity-25 filter grayscale contrast-140 brightness-85 scale-105 transition-opacity duration-700" />';
  } else if (mode == 'bloom') {
    imgTag =
        '<img src="${imageBgs['bloom']}" alt="Sleek Liquid Background" class="absolute inset-0 w-full h-full object-cover opacity-25 dark:opacity-30 filter grayscale contrast-135 mix-blend-overlay scale-105 transition-opacity duration-700" />';
  }

  final html =
      '''
<div class="absolute inset-0 z-0 pointer-events-none overflow-hidden select-none rounded-3xl">
  $imgTag
  <video autoplay loop muted playsinline aria-hidden="true" class="w-full h-full object-cover $videoClass">
    <source src="$videoSrc" type="video/mp4" />
  </video>
  <div class="absolute inset-0 bg-gradient-to-b from-white/40 via-white/20 to-slate-50 dark:from-black/60 dark:via-black/40 dark:to-black"></div>
</div>
''';

  return Raw(html);
}
