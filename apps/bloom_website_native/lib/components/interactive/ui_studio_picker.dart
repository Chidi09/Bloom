import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

class _ColorToken {
  final String id;
  final String bg;
  final String text;
  final String hex;

  const _ColorToken({
    required this.id,
    required this.bg,
    required this.text,
    required this.hex,
  });
}

const _colors = <String, _ColorToken>{
  'purple': _ColorToken(
    id: 'purple',
    bg: 'bg-purple-600',
    text: 'text-purple-600 dark:text-purple-400',
    hex: '#8B5CF6',
  ),
  'pink': _ColorToken(
    id: 'pink',
    bg: 'bg-pink-600',
    text: 'text-pink-600 dark:text-pink-400',
    hex: '#FF4B8B',
  ),
  'blue': _ColorToken(
    id: 'blue',
    bg: 'bg-blue-600',
    text: 'text-blue-600 dark:text-blue-400',
    hex: '#3B82F6',
  ),
  'emerald': _ColorToken(
    id: 'emerald',
    bg: 'bg-emerald-600',
    text: 'text-emerald-600 dark:text-emerald-400',
    hex: '#10B981',
  ),
  'amber': _ColorToken(
    id: 'amber',
    bg: 'bg-amber-600',
    text: 'text-amber-600 dark:text-amber-400',
    hex: '#F59E0B',
  ),
  'rose': _ColorToken(
    id: 'rose',
    bg: 'bg-rose-600',
    text: 'text-rose-600 dark:text-rose-400',
    hex: '#F43F5E',
  ),
};

BloomNode uiStudioPicker() {
  final accentColor = signal('purple');
  final radius = signal(12);
  final activeCategory = signal('all');

  // Interactive mock states
  final sheetOpen = signal(false);
  final switchState = signal(true);
  final checkboxState = signal(true);
  final progressVal = signal(72);
  final selectedDate = signal(14);
  final selectedSegment = signal('day');

  return Div(
    className:
        'glass-panel rounded-[2.5rem] overflow-hidden shadow-2xl grid '
        'grid-cols-1 lg:grid-cols-12 relative border border-slate-200/60 '
        'dark:border-zinc-800 bg-white dark:bg-black text-left',
    children: [
      // Left Sidebar: Token Controls
      Div(
        className:
            'lg:col-span-3 bg-slate-50/60 dark:bg-zinc-950/90 border-b '
            'lg:border-b-0 lg:border-r border-slate-200/60 dark:border-zinc-800 '
            'p-6 sm:p-8 space-y-6 flex flex-col justify-between',
        children: [
          Div(
            className: 'space-y-6',
            children: [
              Div(
                className: 'flex items-center justify-between',
                children: [
                  Div(
                    className:
                        'text-xs font-bold text-slate-900 dark:text-white '
                        'uppercase tracking-widest font-mono flex items-center gap-2',
                    children: [
                      hugeIcon(
                        'sparkles',
                        className: 'w-4 h-4 text-purple-400',
                      ),
                      Span(text: 'shadcn / Mobile UI'),
                    ],
                  ),
                  Span(
                    className:
                        'px-2 py-0.5 rounded text-[10px] font-mono font-bold '
                        'border border-slate-300 dark:border-zinc-700',
                    text: 'v2.5',
                  ),
                ],
              ),

              // Accent Color Tokens
              Div(
                className: 'space-y-3',
                children: [
                  Div(
                    className:
                        'text-xs font-mono font-bold text-slate-500 '
                        'dark:text-slate-400 uppercase',
                    text: 'Accent Token',
                  ),
                  Div(
                    className: 'flex flex-wrap gap-2.5',
                    children: [
                      for (final entry in _colors.entries)
                        Live(() {
                          final isSelected = accentColor.value == entry.key;
                          return Button(
                            attrs: {'type': 'button'},
                            onClick: (_) => accentColor.value = entry.key,
                            className:
                                'w-7 h-7 rounded-full ${entry.value.bg} transition-all cursor-pointer ${isSelected ? 'ring-2 ring-offset-2 ring-offset-white dark:ring-offset-black ring-slate-400 scale-110' : 'opacity-80 hover:opacity-100 hover:scale-105'}',
                          );
                        }),
                    ],
                  ),
                ],
              ),

              // Border Radius Slider
              Div(
                className: 'space-y-3',
                children: [
                  Div(
                    className:
                        'flex justify-between items-center text-xs font-mono '
                        'text-slate-500 dark:text-slate-400 uppercase',
                    children: [
                      Span(className: 'font-bold', text: 'Border Radius'),
                      Live(() {
                        final r = radius.value;
                        return Span(
                          className:
                              'font-bold text-slate-900 dark:text-white font-mono',
                          text: '${(r / 16).toStringAsFixed(2)}rem (${r}px)',
                        );
                      }),
                    ],
                  ),
                  Live(() {
                    final color =
                        _colors[accentColor.value] ?? _colors['purple']!;
                    return Input(
                      attrs: {
                        'type': 'range',
                        'min': '0',
                        'max': '24',
                        'value': '${radius.value}',
                      },
                      onInput: (e) {
                        final val = int.tryParse(e.value ?? '') ?? 12;
                        radius.value = val;
                      },
                      className:
                          'w-full h-1.5 bg-slate-200 dark:bg-zinc-800 rounded-lg '
                          'appearance-none cursor-pointer',
                      style: 'accent-color: ${color.hex};',
                    );
                  }),
                ],
              ),

              // Filter Category Buttons
              Div(
                className: 'space-y-2 pt-2',
                children: [
                  Div(
                    className:
                        'text-xs font-mono font-bold text-slate-500 '
                        'dark:text-slate-400 uppercase block',
                    text: 'Filter Components',
                  ),
                  Div(
                    className: 'flex flex-wrap gap-1.5 font-mono text-[11px]',
                    children: [
                      for (final cat in [
                        ('all', 'All'),
                        ('buttons', 'Buttons & Badges'),
                        ('inputs', 'Inputs & Forms'),
                        ('cards', 'Cards & Avatars'),
                        ('nav', 'Nav & Feedback'),
                      ])
                        Live(() {
                          final isActive = activeCategory.value == cat.$1;
                          final color =
                              _colors[accentColor.value] ?? _colors['purple']!;
                          return Button(
                            attrs: {'type': 'button'},
                            onClick: (_) => activeCategory.value = cat.$1,
                            className:
                                'px-2.5 py-1 rounded-lg transition-all cursor-pointer ${isActive ? '${color.bg} text-white font-bold' : 'bg-slate-200/60 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'}',
                            text: cat.$2,
                          );
                        }),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Trigger Toast Button
          Live(() {
            final r = radius.value;
            return Button(
              attrs: {
                'type': 'button',
                'onclick':
                    "window.dispatchEvent(new CustomEvent('bloom:toast', { detail: { title: 'Token System Live', message: 'Accent: ${accentColor.value.toUpperCase()} | Radius: ${r}px', type: '${accentColor.value == 'emerald' ? 'emerald' : 'purple'}' } }));",
              },
              className:
                  'w-full py-2.5 bg-slate-900 dark:bg-white text-white '
                  'dark:text-slate-900 font-bold text-xs shadow-md transition '
                  'cursor-pointer flex items-center justify-center gap-2',
              style: 'border-radius: ${r}px;',
              children: [
                hugeIcon('sparkles', className: 'w-4 h-4'),
                const Text('Trigger Toast Event'),
              ],
            );
          }),
        ],
      ),

      // Right Canvas: 12 Interactive Components
      Div(
        className: 'lg:col-span-9 p-6 sm:p-8 space-y-10',
        children: [
          // CATEGORY 1: BUTTONS & BADGES
          Live(() {
            final cat = activeCategory.value;
            if (cat != 'all' && cat != 'buttons') return Div();

            final color = _colors[accentColor.value] ?? _colors['purple']!;
            final r = radius.value;

            return Div(
              className: 'space-y-4',
              children: [
                Div(
                  className:
                      'text-xs font-mono font-bold text-slate-500 dark:text-slate-400 '
                      'uppercase tracking-widest flex items-center justify-between '
                      'border-b border-slate-200 dark:border-zinc-800 pb-2',
                  children: [
                    Div(
                      className: 'flex items-center gap-2',
                      children: [
                        hugeIcon('zap', className: 'w-3.5 h-3.5 ${color.text}'),
                        Span(text: 'Buttons & Badges (cva primitives)'),
                      ],
                    ),
                  ],
                ),
                Div(
                  className:
                      'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4',
                  children: [
                    // Card 1: Button Variants
                    _renderStudioCard(
                      r: r,
                      title: 'Button Variants',
                      desc: 'Primary, Secondary, Outline, Destructive',
                      content: Div(
                        className: 'flex flex-wrap gap-2',
                        children: [
                          Button(
                            className:
                                'px-3 py-1.5 text-xs font-bold text-white shadow',
                            style:
                                'border-radius: ${r}px; background-color: ${color.hex};',
                            text: 'Primary',
                          ),
                          Button(
                            className:
                                'px-3 py-1.5 text-xs font-bold bg-slate-200 '
                                'dark:bg-zinc-800 text-slate-900 dark:text-white',
                            style: 'border-radius: ${r}px;',
                            text: 'Secondary',
                          ),
                          Button(
                            className:
                                'px-3 py-1.5 text-xs font-bold border border-slate-300 '
                                'dark:border-zinc-700 text-slate-700 dark:text-slate-300',
                            style: 'border-radius: ${r}px;',
                            text: 'Outline',
                          ),
                          Button(
                            className:
                                'px-3 py-1.5 text-xs font-bold bg-rose-600 text-white',
                            style: 'border-radius: ${r}px;',
                            text: 'Delete',
                          ),
                        ],
                      ),
                    ),

                    // Card 2: Icon & Loading Buttons
                    _renderStudioCard(
                      r: r,
                      title: 'Icon & Loading Buttons',
                      desc: 'With leading icons & spinners',
                      content: Div(
                        className: 'flex flex-wrap items-center gap-2',
                        children: [
                          Button(
                            className:
                                'px-3 py-1.5 text-xs font-bold text-white flex '
                                'items-center gap-1.5 shadow',
                            style:
                                'border-radius: ${r}px; background-color: ${color.hex};',
                            children: [
                              hugeIcon('code', className: 'w-3 h-3 text-white'),
                              const Text('Add Item'),
                            ],
                          ),
                          Button(
                            className:
                                'px-3 py-1.5 text-xs font-bold bg-slate-200 '
                                'dark:bg-zinc-800 text-slate-900 dark:text-white '
                                'flex items-center gap-1.5',
                            style: 'border-radius: ${r}px;',
                            children: [
                              hugeIcon(
                                'refresh',
                                className: 'w-3 h-3 animate-spin',
                              ),
                              const Text('Saving...'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Card 3: Badges Collection
                    _renderStudioCard(
                      r: r,
                      title: 'Badge Variants',
                      desc: 'Status tags & counts',
                      content: Div(
                        className: 'flex flex-wrap gap-2',
                        children: [
                          Span(
                            className:
                                'px-2 py-0.5 text-xs font-bold text-white',
                            style:
                                'border-radius: ${r}px; background-color: ${color.hex};',
                            text: 'Default',
                          ),
                          Span(
                            className:
                                'px-2 py-0.5 text-xs font-bold bg-slate-200 '
                                'dark:bg-zinc-800 text-slate-800 dark:text-slate-200',
                            style: 'border-radius: ${r}px;',
                            text: 'Secondary',
                          ),
                          Span(
                            className:
                                'px-2 py-0.5 text-xs font-bold bg-emerald-500/10 '
                                'text-emerald-600 dark:text-emerald-400 border '
                                'border-emerald-500/20',
                            style: 'border-radius: ${r}px;',
                            text: 'Success',
                          ),
                          Span(
                            className:
                                'px-2 py-0.5 text-xs font-bold bg-rose-500/10 '
                                'text-rose-600 dark:text-rose-400 border '
                                'border-rose-500/20',
                            style: 'border-radius: ${r}px;',
                            text: 'Alert',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),

          // CATEGORY 2: INPUTS & FORM CONTROLS
          Live(() {
            final cat = activeCategory.value;
            if (cat != 'all' && cat != 'inputs') return Div();

            final color = _colors[accentColor.value] ?? _colors['purple']!;
            final r = radius.value;

            return Div(
              className: 'space-y-4',
              children: [
                Div(
                  className:
                      'text-xs font-mono font-bold text-slate-500 dark:text-slate-400 '
                      'uppercase tracking-widest flex items-center justify-between '
                      'border-b border-slate-200 dark:border-zinc-800 pb-2',
                  children: [
                    Div(
                      className: 'flex items-center gap-2',
                      children: [
                        hugeIcon(
                          'code',
                          className: 'w-3.5 h-3.5 ${color.text}',
                        ),
                        Span(text: 'Inputs, Textarea & Form Controls'),
                      ],
                    ),
                  ],
                ),
                Div(
                  className:
                      'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4',
                  children: [
                    // Card 4: Text & Search Inputs
                    _renderStudioCard(
                      r: r,
                      title: 'Text & Search Inputs',
                      desc: 'Mobile input fields',
                      content: Div(
                        className: 'space-y-3',
                        children: [
                          Input(
                            attrs: {
                              'type': 'text',
                              'placeholder': 'Search widgets...',
                              'value': '',
                            },
                            className:
                                'w-full bg-slate-50 dark:bg-zinc-950 border '
                                'border-slate-200 dark:border-zinc-800 rounded-lg '
                                'px-3 py-2 text-xs text-slate-900 dark:text-white',
                            style: 'border-radius: ${r}px;',
                          ),
                          Input(
                            attrs: {
                              'type': 'email',
                              'value': 'developer@bloom.dev',
                            },
                            className:
                                'w-full bg-slate-50 dark:bg-zinc-950 border '
                                'border-slate-200 dark:border-zinc-800 rounded-lg '
                                'px-3 py-2 text-xs text-slate-900 dark:text-white',
                            style: 'border-radius: ${r}px;',
                          ),
                        ],
                      ),
                    ),

                    // Card 5: Progress & Range Slider
                    _renderStudioCard(
                      r: r,
                      title: 'Progress & Range Slider',
                      desc: 'Live progress bar',
                      content: Div(
                        className: 'space-y-4',
                        children: [
                          Live(() {
                            final p = progressVal.value;
                            return Div(
                              children: [
                                Div(
                                  className:
                                      'flex justify-between text-xs font-mono mb-1.5 '
                                      'font-semibold',
                                  children: [
                                    Span(text: 'OTA Bundle Upload'),
                                    Span(className: color.text, text: '$p%'),
                                  ],
                                ),
                                Div(
                                  className:
                                      'w-full h-2 bg-slate-200 dark:bg-zinc-800 rounded-full '
                                      'overflow-hidden',
                                  style: 'border-radius: ${r}px;',
                                  children: [
                                    Div(
                                      className:
                                          'h-full rounded-full transition-all duration-200',
                                      style:
                                          'width: $p%; background-color: ${color.hex}; border-radius: ${r}px;',
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }),
                          Input(
                            attrs: {
                              'type': 'range',
                              'min': '0',
                              'max': '100',
                              'value': '${progressVal.value}',
                            },
                            onInput: (e) {
                              final p = int.tryParse(e.value ?? '') ?? 72;
                              progressVal.value = p;
                            },
                            className:
                                'w-full h-1.5 bg-slate-200 dark:bg-zinc-800 rounded-lg '
                                'appearance-none cursor-pointer',
                            style: 'accent-color: ${color.hex};',
                          ),
                        ],
                      ),
                    ),

                    // Card 6: Switches & Checkboxes
                    _renderStudioCard(
                      r: r,
                      title: 'Switches & Checkboxes',
                      desc: 'Binary toggle switches',
                      content: Div(
                        className: 'space-y-3',
                        children: [
                          Div(
                            className: 'flex items-center justify-between',
                            children: [
                              Span(
                                className:
                                    'text-xs font-semibold text-slate-700 dark:text-slate-300',
                                text: 'Push Notifications',
                              ),
                              Live(() {
                                final sw = switchState.value;
                                return Button(
                                  attrs: {'type': 'button'},
                                  onClick: (_) => switchState.value = !sw,
                                  className:
                                      'w-11 h-6 rounded-full p-1 cursor-pointer transition-colors ${sw ? color.bg : 'bg-slate-300 dark:bg-zinc-800'}',
                                  children: [
                                    Div(
                                      className:
                                          'w-4 h-4 bg-white rounded-full transform transition-transform shadow ${sw ? 'translate-x-5' : 'translate-x-0'}',
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                          El(
                            'label',
                            className:
                                'flex items-center gap-2 cursor-pointer text-xs '
                                'font-semibold text-slate-700 dark:text-slate-300',
                            children: [
                              Live(() {
                                final cb = checkboxState.value;
                                return Button(
                                  attrs: {'type': 'button'},
                                  onClick: (_) => checkboxState.value = !cb,
                                  className:
                                      'w-4 h-4 rounded flex items-center justify-center text-white text-[10px] cursor-pointer ${cb ? color.bg : 'border border-slate-400 bg-transparent'}',
                                  text: cb ? '✓' : '',
                                );
                              }),
                              Span(text: 'Auto-update signals state'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),

          // CATEGORY 3: CARDS, AVATARS & ALERTS
          Live(() {
            final cat = activeCategory.value;
            if (cat != 'all' && cat != 'cards') return Div();

            final color = _colors[accentColor.value] ?? _colors['purple']!;
            final r = radius.value;

            return Div(
              className: 'space-y-4',
              children: [
                Div(
                  className:
                      'text-xs font-mono font-bold text-slate-500 dark:text-slate-400 '
                      'uppercase tracking-widest flex items-center justify-between '
                      'border-b border-slate-200 dark:border-zinc-800 pb-2',
                  children: [
                    Div(
                      className: 'flex items-center gap-2',
                      children: [
                        hugeIcon(
                          'sparkles',
                          className: 'w-3.5 h-3.5 ${color.text}',
                        ),
                        Span(text: 'Mobile Cards, Avatars & Alerts'),
                      ],
                    ),
                  ],
                ),
                Div(
                  className:
                      'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4',
                  children: [
                    // Card 7: Payment Wallet Card
                    Div(
                      className:
                          'text-white shadow-xl ${color.bg} border-0 p-6 flex '
                          'flex-col justify-between h-48',
                      style: 'border-radius: ${r}px;',
                      children: [
                        Div(
                          className: 'flex justify-between items-start',
                          children: [
                            Span(
                              className:
                                  'text-xs font-mono font-bold opacity-80 uppercase',
                              text: 'Bloom Wallet',
                            ),
                            hugeIcon('zap', className: 'w-5 h-5 opacity-90'),
                          ],
                        ),
                        Div(
                          children: [
                            Span(
                              className:
                                  'text-[10px] font-mono opacity-70 block mb-1',
                              text: 'Total Balance',
                            ),
                            H3(
                              className:
                                  'text-2xl font-black font-mono tracking-tight',
                              text: r'$14,890.00',
                            ),
                          ],
                        ),
                        Div(
                          className:
                              'flex justify-between items-center text-xs font-mono '
                              'opacity-80',
                          children: [
                            Span(text: '•••• 4892'),
                            Span(text: '10/28'),
                          ],
                        ),
                      ],
                    ),

                    // Card 8: User Profile & Avatar
                    _renderStudioCard(
                      r: r,
                      title: 'User Profile & Avatar',
                      desc: 'Avatar primitive with fallback',
                      content: Div(
                        className: 'flex items-center justify-between',
                        children: [
                          Div(
                            className: 'flex items-center gap-3',
                            children: [
                              Div(
                                className:
                                    'w-10 h-10 rounded-full bg-purple-600 flex '
                                    'items-center justify-center font-bold text-white text-xs',
                                text: 'AR',
                              ),
                              Div(
                                children: [
                                  H4(
                                    className:
                                        'font-bold text-xs text-slate-900 dark:text-white',
                                    text: 'Alex Rivera',
                                  ),
                                  Span(
                                    className:
                                        'text-[10px] font-mono text-slate-500',
                                    text: 'Mobile Lead',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Span(
                            className:
                                'px-2 py-0.5 rounded text-[10px] font-mono font-bold '
                                'bg-emerald-500/10 text-emerald-500 border border-emerald-500/20',
                            style: 'border-radius: ${r}px;',
                            text: 'Active',
                          ),
                        ],
                      ),
                    ),

                    // Card 9: Alert Callout
                    _renderStudioCard(
                      r: r,
                      title: 'Alert Callout Primitive',
                      desc: 'System notifications',
                      content: Div(
                        className:
                            'p-3 rounded-xl bg-slate-50 dark:bg-zinc-950 border '
                            'border-slate-200 dark:border-zinc-800 flex items-start gap-2.5',
                        style: 'border-radius: ${r}px;',
                        children: [
                          hugeIcon(
                            'check-circle',
                            className:
                                'w-4 h-4 text-emerald-500 mt-0.5 shrink-0',
                          ),
                          Div(
                            children: [
                              H5(
                                className:
                                    'font-bold text-xs text-slate-900 dark:text-white',
                                text: 'Deployment Complete',
                              ),
                              P(
                                className:
                                    'text-[11px] text-slate-500 dark:text-slate-400 mt-0.5',
                                text:
                                    'Patch v2.5.1 published to 142 Edge CDN nodes.',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),

          // CATEGORY 4: SHEETS, DATE PICKER & OVERLAYS
          Live(() {
            final cat = activeCategory.value;
            if (cat != 'all' && cat != 'nav') return Div();

            final color = _colors[accentColor.value] ?? _colors['purple']!;
            final r = radius.value;

            return Div(
              className: 'space-y-4',
              children: [
                Div(
                  className:
                      'text-xs font-mono font-bold text-slate-500 dark:text-slate-400 '
                      'uppercase tracking-widest flex items-center justify-between '
                      'border-b border-slate-200 dark:border-zinc-800 pb-2',
                  children: [
                    Div(
                      className: 'flex items-center gap-2',
                      children: [
                        hugeIcon(
                          'code',
                          className: 'w-3.5 h-3.5 ${color.text}',
                        ),
                        Span(text: 'Bottom Sheets, DatePicker & Controls'),
                      ],
                    ),
                  ],
                ),
                Div(
                  className:
                      'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4',
                  children: [
                    // Card 10: Bottom Sheet Drawer Trigger Card
                    _renderStudioCard(
                      r: r,
                      title: 'Bottom Sheet / Drawer',
                      desc: 'Interactive mobile modal overlay',
                      content: Div(
                        className: 'space-y-3',
                        children: [
                          P(
                            className:
                                'text-xs text-slate-500 dark:text-slate-400',
                            text:
                                'Triggers a native-feel mobile bottom sheet with '
                                'custom radius and accent styling.',
                          ),
                          Button(
                            attrs: {'type': 'button'},
                            onClick: (_) => sheetOpen.value = true,
                            className:
                                'w-full py-2 text-xs font-bold text-white shadow '
                                'cursor-pointer',
                            style:
                                'border-radius: ${r}px; background-color: ${color.hex};',
                            text: 'Open Bottom Sheet',
                          ),
                        ],
                      ),
                    ),

                    // Card 11: Segmented Control Card
                    _renderStudioCard(
                      r: r,
                      title: 'Segmented Control',
                      desc: 'Mobile tab selection bar',
                      content: Div(
                        className:
                            'p-1 bg-slate-100 dark:bg-zinc-900 rounded-xl grid '
                            'grid-cols-3 gap-1',
                        style: 'border-radius: ${r}px;',
                        children: [
                          for (final seg in [
                            ('day', 'Day'),
                            ('week', 'Week'),
                            ('month', 'Month'),
                          ])
                            Live(() {
                              final isSel = selectedSegment.value == seg.$1;
                              return Button(
                                attrs: {'type': 'button'},
                                onClick: (_) => selectedSegment.value = seg.$1,
                                className:
                                    'py-1.5 text-xs font-mono font-bold transition-all cursor-pointer ${isSel ? 'bg-white dark:bg-black text-slate-900 dark:text-white shadow' : 'text-slate-500'}',
                                style: 'border-radius: ${r * 0.75}px;',
                                text: seg.$2,
                              );
                            }),
                        ],
                      ),
                    ),

                    // Card 12: Mobile DatePicker Card
                    _renderStudioCard(
                      r: r,
                      title: 'Mobile DatePicker',
                      desc: 'Calendar grid with day selection',
                      content: Div(
                        className:
                            'grid grid-cols-7 gap-1 text-center font-mono text-xs',
                        children: [
                          for (int day = 10; day <= 23; day++)
                            Live(() {
                              final isDaySel = selectedDate.value == day;
                              return Button(
                                attrs: {'type': 'button'},
                                onClick: (_) => selectedDate.value = day,
                                className:
                                    'py-1 rounded text-center transition cursor-pointer ${isDaySel ? '${color.bg} text-white font-bold' : 'hover:bg-slate-100 dark:hover:bg-zinc-800 text-slate-700 dark:text-slate-300'}',
                                style: 'border-radius: ${r * 0.5}px;',
                                text: '$day',
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),

      // Interactive Sheet Modal Overlay
      Live(() {
        if (!sheetOpen.value) return Div();

        final color = _colors[accentColor.value] ?? _colors['purple']!;
        final r = radius.value;

        return Div(
          className:
              'fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-end '
              'justify-center p-4',
          children: [
            Div(
              className:
                  'w-full max-w-lg bg-white dark:bg-zinc-950 border '
                  'border-slate-200 dark:border-zinc-800 p-6 space-y-6 shadow-2xl animate-fade-in',
              style: 'border-radius: ${r * 1.5}px;',
              children: [
                Div(
                  className: 'flex items-center justify-between',
                  children: [
                    Div(
                      children: [
                        H3(
                          className:
                              'text-base font-bold text-slate-900 dark:text-white',
                          text: 'Bloom Flutter Architecture',
                        ),
                        P(
                          className:
                              'text-xs text-slate-500 dark:text-slate-400 mt-0.5',
                          text:
                              'Signals state and Shorebird OTA integration spec',
                        ),
                      ],
                    ),
                    Button(
                      attrs: {'type': 'button'},
                      onClick: (_) => sheetOpen.value = false,
                      className:
                          'text-slate-400 hover:text-slate-600 '
                          'dark:hover:text-white cursor-pointer font-bold',
                      text: '✕',
                    ),
                  ],
                ),
                Div(
                  className:
                      'p-4 bg-purple-500/10 border border-purple-500/20 '
                      'rounded-xl space-y-1',
                  style: 'border-radius: ${r}px;',
                  children: [
                    Span(
                      className:
                          'font-bold text-xs text-purple-600 dark:text-purple-400 '
                          'block',
                      text: '⚡ Signals State Synced',
                    ),
                    P(
                      className: 'text-xs text-slate-600 dark:text-slate-300',
                      text:
                          'Zero-boilerplate reactive binding active across all '
                          'components.',
                    ),
                  ],
                ),
                Div(
                  className: 'flex justify-end gap-2',
                  children: [
                    Button(
                      attrs: {'type': 'button'},
                      onClick: (_) => sheetOpen.value = false,
                      className:
                          'px-4 py-2 border border-slate-300 dark:border-zinc-700 '
                          'text-xs font-bold text-slate-700 dark:text-slate-300 '
                          'cursor-pointer',
                      style: 'border-radius: ${r}px;',
                      text: 'Cancel',
                    ),
                    Button(
                      attrs: {
                        'type': 'button',
                        'onclick':
                            "window.dispatchEvent(new CustomEvent('bloom:toast', { detail: { title: 'Sheet Confirmed', message: 'Mobile overlay state updated successfully.', type: 'emerald' } }));",
                      },
                      onClick: (_) => sheetOpen.value = false,
                      className:
                          'px-4 py-2 text-xs font-bold text-white shadow '
                          'cursor-pointer',
                      style:
                          'border-radius: ${r}px; background-color: ${color.hex};',
                      text: 'Confirm Action',
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

BloomNode _renderStudioCard({
  required int r,
  required String title,
  required String desc,
  required BloomNode content,
}) {
  return Div(
    className:
        'p-5 rounded-2xl bg-white dark:bg-zinc-950 border border-slate-200 '
        'dark:border-zinc-800 shadow-sm flex flex-col justify-between space-y-4',
    style: 'border-radius: ${r}px;',
    children: [
      Div(
        children: [
          H4(
            className: 'font-bold text-xs text-slate-900 dark:text-white',
            text: title,
          ),
          P(
            className: 'text-[11px] text-slate-500 dark:text-slate-400 mt-0.5',
            text: desc,
          ),
        ],
      ),
      content,
    ],
  );
}
