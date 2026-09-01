import 'package:bloom_ui/bloom_ui.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(const BloomUiExampleApp());
}

class BloomUiExampleApp extends StatefulWidget {
  const BloomUiExampleApp({super.key});

  @override
  State<BloomUiExampleApp> createState() => _BloomUiExampleAppState();
}

class _BloomUiExampleAppState extends State<BloomUiExampleApp> {
  BloomThemeMode _themeMode = BloomThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return BloomApp(
      title: 'Bloom UI Showcase',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: BloomTheme.light,
      darkTheme: BloomTheme.dark,
      home: ShowcaseScreen(
        isDark: _themeMode == BloomThemeMode.dark,
        onToggleTheme: () {
          setState(() {
            _themeMode = _themeMode == BloomThemeMode.dark
                ? BloomThemeMode.light
                : BloomThemeMode.dark;
          });
        },
      ),
    );
  }
}

class ShowcaseScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const ShowcaseScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  bool _switchVal = true;
  bool? _checkVal = true;
  double _sliderVal = 0.45;
  String _selectVal = 'nova';

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return BloomScaffold(
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Row(
                    children: [
                      Text(
                        '🌸 Bloom UI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(width: 8),
                      BloomBadge(
                        variant: BloomBadgeVariant.secondary,
                        size: BloomBadgeSize.sm,
                        child: Text('v0.1.0'),
                      ),
                    ],
                  ),
                  const Spacer(),
                  BloomPressable(
                    onTap: widget.onToggleTheme,
                    borderRadius: BorderRadius.circular(context.bloomRadius.md),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: BloomIcon(
                          widget.isDark ? BloomIcons.lightMode : BloomIcons.darkMode,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const BloomSeparator(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cards & Forms
                BloomCard(
                  header: const BloomCardHeader(
                    title: BloomCardTitle('Interactive Primitives'),
                    description: BloomCardDescription('Zero-dependency Flutter widgets styled with shadcn base-nova.'),
                  ),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          BloomButton(
                            variant: BloomButtonVariant.defaultVariant,
                            onPressed: () {
                              BloomSonner.success(context, 'Primary action clicked!');
                            },
                            child: const Text('Default'),
                          ),
                          BloomButton(
                            variant: BloomButtonVariant.secondary,
                            onPressed: () {},
                            child: const Text('Secondary'),
                          ),
                          BloomButton(
                            variant: BloomButtonVariant.outline,
                            onPressed: () {},
                            child: const Text('Outline'),
                          ),
                          BloomButton(
                            variant: BloomButtonVariant.ghost,
                            onPressed: () {},
                            child: const Text('Ghost'),
                          ),
                          BloomButton(
                            variant: BloomButtonVariant.destructive,
                            onPressed: () {
                              BloomSonner.error(context, 'Destructive event triggered.');
                            },
                            child: const Text('Destructive'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: BloomInput(
                              placeholder: 'Search components...',
                              leading: const BloomIcon(BloomIcons.search, size: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          BloomSelect<String>(
                            value: _selectVal,
                            items: const [
                              BloomSelectItem(value: 'nova', label: 'Nova'),
                              BloomSelectItem(value: 'vega', label: 'Vega'),
                              BloomSelectItem(value: 'lyra', label: 'Lyra'),
                            ],
                            onChanged: (v) => setState(() => _selectVal = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          BloomCheckbox(
                            checked: _checkVal,
                            label: const Text('Enabled'),
                            onChanged: (v) => setState(() => _checkVal = v),
                          ),
                          const SizedBox(width: 16),
                          BloomSwitch(
                            checked: _switchVal,
                            label: const Text('Notifications'),
                            onChanged: (v) => setState(() => _switchVal = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      BloomSlider(
                        value: _sliderVal,
                        onChanged: (v) => setState(() => _sliderVal = v),
                      ),
                    ],
                  ),
                  footer: BloomCardFooter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        BloomButton(
                          variant: BloomButtonVariant.outline,
                          size: BloomButtonSize.sm,
                          onPressed: () {},
                          child: const Text('Reset'),
                        ),
                        const SizedBox(width: 8),
                        BloomButton(
                          size: BloomButtonSize.sm,
                          onPressed: () {
                            BloomSonner.success(context, 'Saved preferences!');
                          },
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Charts demo
                BloomCard(
                  header: const BloomCardHeader(
                    title: BloomCardTitle('Pure Dart Charts'),
                    description: BloomCardDescription('Responsive area and bar charts with drag tooltip tracking.'),
                  ),
                  content: BloomChart(
                    type: BloomChartType.area,
                    height: 220,
                    data: BloomChartData(
                      labels: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                      series: [
                        BloomChartSeries(
                          name: 'Desktop',
                          values: const [186, 305, 237, 73, 209, 214],
                          color: colors.primary,
                        ),
                        BloomChartSeries(
                          name: 'Mobile',
                          values: const [80, 200, 120, 190, 130, 140],
                          color: BloomColors.petalPink,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
