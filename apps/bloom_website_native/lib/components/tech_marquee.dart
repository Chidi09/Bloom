import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode techMarquee() {
  final logos = const [
    (
      'Google Cloud',
      'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/googlecloud/googlecloud-original.svg',
      'h-8',
      '',
    ),
    (
      'Flutter 3.29',
      'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/flutter/flutter-original.svg',
      'h-7',
      '',
    ),
    (
      'Dart 3.7',
      'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/dart/dart-original.svg',
      'h-7',
      '',
    ),
    (
      'Firebase',
      'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/firebase/firebase-plain.svg',
      'h-8',
      '',
    ),
    (
      'GitHub',
      'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/github/github-original.svg',
      'h-7',
      'dark:invert',
    ),
    (
      'iOS / Apple',
      'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/apple/apple-original.svg',
      'h-7',
      'dark:invert',
    ),
    (
      'Android',
      'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/android/android-original.svg',
      'h-7',
      '',
    ),
  ];

  return Section(
    className:
        'py-12 border-y border-slate-200/50 dark:border-zinc-800 '
        'bg-white/40 dark:bg-black/40 backdrop-blur-md '
        'overflow-hidden relative',
    children: [
      Div(
        className:
            'absolute left-0 top-0 bottom-0 w-32 bg-gradient-to-r '
            'from-slate-50 dark:from-black to-transparent z-10 '
            'pointer-events-none',
      ),
      Div(
        className:
            'absolute right-0 top-0 bottom-0 w-32 bg-gradient-to-l '
            'from-slate-50 dark:from-black to-transparent z-10 '
            'pointer-events-none',
      ),
      P(
        className:
            'text-center text-[10px] font-mono uppercase '
            'tracking-widest text-slate-500 dark:text-slate-400 mb-8 '
            'font-bold',
        text: 'BUILT ON THE SHOULDERS OF GIANTS',
      ),
      Div(
        className: 'flex overflow-hidden group w-[200%] select-none',
        children: [
          Div(
            className:
                'flex space-x-16 sm:space-x-24 items-center '
                'animate-marquee opacity-90 dark:opacity-80 '
                'transition-all duration-500',
            children: [
              for (var loop = 0; loop < 2; loop++)
                for (final (name, url, height, className) in logos)
                  Div(
                    className:
                        'flex items-center gap-3 font-bold text-lg text-slate-900 '
                        'dark:text-white shrink-0',
                    children: [
                      Img(
                        src: url,
                        alt: '$name logo',
                        className: '$height w-auto object-contain $className',
                        attrs: const {'loading': 'eager', 'decoding': 'async'},
                      ),
                      Span(text: name),
                    ],
                  ),
            ],
          ),
        ],
      ),
    ],
  );
}
