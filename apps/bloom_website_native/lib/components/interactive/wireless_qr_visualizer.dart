import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

BloomNode wirelessQrVisualizer() {
  final activeTab = signal('wireless');
  final isPairing = signal(false);

  return Div(
    className:
        'p-8 sm:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur '
        'border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl '
        'mx-auto space-y-8 text-left',
    children: [
      // Header Tabs
      Div(
        className:
            'flex flex-col sm:flex-row sm:items-center justify-between gap-4 '
            'pb-6 border-b border-slate-200 dark:border-zinc-800',
        children: [
          Div(
            children: [
              Div(
                className: 'flex items-center gap-2 mb-1',
                children: [
                  hugeIcon(
                    'sparkles',
                    className: 'w-5 h-5 text-blue-600 dark:text-blue-400',
                  ),
                  H3(
                    className:
                        'text-xl font-bold text-slate-900 dark:text-white '
                        'tracking-tight',
                    text: 'Wireless Pairing & Instant QR Preview Engine',
                  ),
                ],
              ),
              P(
                className: 'text-xs text-slate-600 dark:text-slate-400',
                text:
                    'Eliminate USB cable tethering. Pair iOS & Android devices '
                    'over Wi-Fi with instant QR scanning.',
              ),
            ],
          ),
          Div(
            className: 'flex items-center gap-2',
            children: [
              Live(() {
                final isWireless = activeTab.value == 'wireless';
                return Button(
                  attrs: {'type': 'button'},
                  onClick: (_) => activeTab.value = 'wireless',
                  className:
                      'px-4 py-2 rounded-xl text-xs font-mono font-bold '
                      'transition-all border cursor-pointer ${isWireless ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-950 border-slate-900 dark:border-white shadow-md' : 'bg-slate-100 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-zinc-800 hover:text-slate-900 dark:hover:text-white'}',
                  text: r'$ bloom dev --wireless',
                );
              }),
              Live(() {
                final isQr = activeTab.value == 'qr';
                return Button(
                  attrs: {'type': 'button'},
                  onClick: (_) => activeTab.value = 'qr',
                  className:
                      'px-4 py-2 rounded-xl text-xs font-mono font-bold '
                      'transition-all border cursor-pointer ${isQr ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-950 border-slate-900 dark:border-white shadow-md' : 'bg-slate-100 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-zinc-800 hover:text-slate-900 dark:hover:text-white'}',
                  text: r'$ bloom build --dev',
                );
              }),
            ],
          ),
        ],
      ),

      // Main Body
      Live(() {
        final currentTab = activeTab.value;

        if (currentTab == 'wireless') {
          return Div(
            className: 'grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch',
            children: [
              // Left: Connected Devices List
              Div(
                className:
                    'lg:col-span-6 p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 '
                    'border border-slate-200 dark:border-zinc-800 space-y-4',
                children: [
                  Div(
                    className:
                        'flex items-center justify-between text-xs font-mono '
                        'font-bold text-slate-500 dark:text-slate-400 pb-2 '
                        'border-b border-slate-200 dark:border-zinc-800',
                    children: [
                      Span(text: 'Discovered Network Targets'),
                      Span(
                        className: 'text-emerald-600 dark:text-emerald-400',
                        text: 'PORT: 5555',
                      ),
                    ],
                  ),
                  Div(
                    className: 'space-y-3',
                    children: [
                      Div(
                        className:
                            'p-3.5 rounded-xl bg-white dark:bg-zinc-900 border '
                            'border-slate-200 dark:border-zinc-800 flex '
                            'items-center justify-between shadow-sm',
                        children: [
                          Div(
                            className: 'flex items-center gap-3',
                            children: [
                              Div(
                                className:
                                    'p-2 rounded-lg bg-blue-500/10 text-blue-600 '
                                    'dark:text-blue-400',
                                children: [
                                  hugeIcon('code', className: 'w-4 h-4'),
                                ],
                              ),
                              Div(
                                children: [
                                  H4(
                                    className:
                                        'text-xs font-bold text-slate-900 '
                                        'dark:text-white',
                                    text: 'iPhone 16 Pro (Wireless)',
                                  ),
                                  Span(
                                    className:
                                        'text-[10px] font-mono text-slate-500 '
                                        'dark:text-slate-400',
                                    text: '192.168.1.142 · iOS 18.2',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Span(
                            className:
                                'flex items-center gap-1 text-[11px] '
                                'text-emerald-600 dark:text-emerald-400 font-mono '
                                'font-bold',
                            text: '✓ Paired',
                          ),
                        ],
                      ),
                      Div(
                        className:
                            'p-3.5 rounded-xl bg-white dark:bg-zinc-900 border '
                            'border-slate-200 dark:border-zinc-800 flex '
                            'items-center justify-between shadow-sm',
                        children: [
                          Div(
                            className: 'flex items-center gap-3',
                            children: [
                              Div(
                                className:
                                    'p-2 rounded-lg bg-teal-500/10 text-teal-600 '
                                    'dark:text-teal-400',
                                children: [
                                  hugeIcon('code', className: 'w-4 h-4'),
                                ],
                              ),
                              Div(
                                children: [
                                  H4(
                                    className:
                                        'text-xs font-bold text-slate-900 '
                                        'dark:text-white',
                                    text: 'Pixel 9 Pro (ADB Wi-Fi)',
                                  ),
                                  Span(
                                    className:
                                        'text-[10px] font-mono text-slate-500 '
                                        'dark:text-slate-400',
                                    text: '192.168.1.188 · Android 15',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Span(
                            className:
                                'flex items-center gap-1 text-[11px] '
                                'text-emerald-600 dark:text-emerald-400 font-mono '
                                'font-bold',
                            text: '✓ Paired',
                          ),
                        ],
                      ),
                    ],
                  ),
                  Button(
                    attrs: {'type': 'button'},
                    onClick: (_) {
                      isPairing.value = true;
                      Future.delayed(
                        const Duration(milliseconds: 600),
                        () => isPairing.value = false,
                      );
                    },
                    className:
                        'w-full py-2.5 rounded-xl bg-slate-900 dark:bg-white text-white '
                        'dark:text-slate-900 font-bold text-xs shadow-md '
                        'hover:bg-slate-800 dark:hover:bg-slate-100 transition '
                        'cursor-pointer flex items-center justify-center gap-2',
                    children: [
                      hugeIcon(
                        'sparkles',
                        className:
                            'w-3.5 h-3.5 text-purple-400 dark:text-purple-600',
                      ),
                      Live(() {
                        return Text(
                          isPairing.value
                              ? 'Scanning Local Subnet...'
                              : 'Rescan Wi-Fi Devices',
                        );
                      }),
                    ],
                  ),
                ],
              ),

              // Right: Realtime Console Stream
              Div(
                className:
                    'lg:col-span-6 p-6 rounded-2xl bg-slate-950 dark:bg-black '
                    'border border-slate-800 dark:border-zinc-800 font-mono text-xs '
                    'text-slate-300 space-y-2 flex flex-col justify-between shadow-xl',
                children: [
                  Div(
                    className: 'space-y-1.5',
                    children: [
                      Div(
                        className: 'text-purple-400 font-bold',
                        text: r'$ bloom dev --wireless --target=all',
                      ),
                      Div(
                        className: 'text-slate-400',
                        text:
                            '[DISCOVERY] Broadcasted mDNS probe on 224.0.0.251:5353',
                      ),
                      Div(
                        className: 'text-emerald-400',
                        text:
                            '[TARGET_1] iPhone 16 Pro bound at '
                            'ws://192.168.1.142:5555',
                      ),
                      Div(
                        className: 'text-emerald-400',
                        text:
                            '[TARGET_2] Pixel 9 Pro bound at ws://192.168.1.188:5555',
                      ),
                      Div(
                        className: 'text-slate-300',
                        text:
                            '[HOT_RELOAD] State synchronization synced across 2 '
                            'devices',
                      ),
                    ],
                  ),
                  Div(
                    className:
                        'pt-3 border-t border-slate-800 text-[10px] text-slate-500 '
                        'flex items-center justify-between',
                    children: [
                      Span(text: 'Signals State Preserved'),
                      Span(
                        className: 'text-emerald-400 font-bold',
                        text: 'AOT SYNC LIVE',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        }

        // QR Code Preview Tab
        return Div(
          className: 'grid grid-cols-1 lg:grid-cols-12 gap-8 items-center',
          children: [
            // Left: Simulated QR Code Box
            Div(
              className:
                  'lg:col-span-5 p-8 rounded-2xl bg-white dark:bg-zinc-950 '
                  'border border-slate-200 dark:border-zinc-800 flex flex-col '
                  'items-center text-center space-y-4 shadow-xl',
              children: [
                Div(
                  className:
                      'w-48 h-48 rounded-2xl bg-slate-900 dark:bg-black border-2 '
                      'border-purple-500/40 p-4 flex items-center justify-center '
                      'relative group overflow-hidden',
                  children: [
                    Div(
                      className:
                          'w-full h-full border border-dashed border-purple-400/60 '
                          'rounded-xl flex flex-col items-center justify-center '
                          'space-y-2',
                      children: [
                        hugeIcon(
                          'sparkles',
                          className: 'w-12 h-12 text-purple-400',
                        ),
                        Span(
                          className:
                              'text-[10px] font-mono text-purple-300 font-bold',
                          text: 'SCAN TO INSTALL DEV BUILD',
                        ),
                      ],
                    ),
                  ],
                ),
                Span(
                  className:
                      'text-xs font-mono text-slate-600 dark:text-slate-400',
                  text: 'Camera scan opens Bloom Dev Container instantly.',
                ),
              ],
            ),

            // Right: QR Distribution Info
            Div(
              className: 'lg:col-span-7 space-y-4 text-xs font-mono',
              children: [
                Div(
                  className:
                      'p-4 rounded-xl bg-slate-50 dark:bg-zinc-950 border '
                      'border-slate-200 dark:border-zinc-800 space-y-1',
                  children: [
                    Span(
                      className:
                          'text-slate-400 text-[10px] uppercase font-bold',
                      text: 'Direct Preview URL',
                    ),
                    Div(
                      className:
                          'text-purple-600 dark:text-purple-400 font-bold',
                      text: 'https://preview.bloom.dev/app/dpl_89f2a01',
                    ),
                  ],
                ),
                Div(
                  className:
                      'p-4 rounded-xl bg-slate-50 dark:bg-zinc-950 border '
                      'border-slate-200 dark:border-zinc-800 space-y-1',
                  children: [
                    Span(
                      className:
                          'text-slate-400 text-[10px] uppercase font-bold',
                      text: 'Cryptographic Binary Digest',
                    ),
                    Div(
                      className: 'text-slate-700 dark:text-slate-300',
                      text: 'SHA256: 8f9a2b4e7c1d3f0a9e8b7c6d5e4f3a2b1c0d9e8f',
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      }),
    ],
  );
}
