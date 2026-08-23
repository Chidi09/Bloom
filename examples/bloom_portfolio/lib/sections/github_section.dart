/// GitHub contribution heat-map and open-source metrics section.
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:web/web.dart' as web;
import '../config.dart';
import '../plugins/github_calendar.dart';
import '../plugins/lucide_icons.dart';

/// GitHub contribution graph component.
class GitHubSectionComponent {
  final Ref<Object> _calendarRef = Ref<Object>();

  BloomNode build() {
    return Mount(
      Section(
        attrs: {
          'id': 'activity',
          ...aria(
            role: AriaRole.region,
            label: 'Open Source Contribution Activity',
          ),
        },
        className: 'py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-zinc-900',
        children: [
          // Section Header
          Div(
            className: 'mb-16',
            children: [
              Span(
                className:
                    'font-mono text-xs text-indigo-400 font-semibold tracking-widest uppercase mb-2 block',
                text: '03. Open Source Ecosystem',
              ),
              H2(
                className: 'text-3xl sm:text-4xl font-bold tracking-tight text-zinc-50 mb-4',
                text: 'Continuous Contributions',
              ),
              P(
                className: 'text-zinc-400 text-sm sm:text-base max-w-2xl',
                text:
                    'Active participation across compiler toolchains, systems runtimes, and distributed storage infrastructure.',
              ),
            ],
          ),

          // Activity Stats Metric Cards
          Div(
            className: 'grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8',
            children: [
              _metricCard('2,480+', 'Commits This Year', LucideIconName.activity),
              _metricCard('42', 'Repositories Authored', LucideIconName.code),
              _metricCard('180+', 'Pull Requests Merged', LucideIconName.checkCircle2),
              _metricCard('99.9%', 'Pipeline Pass Rate', LucideIconName.cpu),
            ],
          ),

          // GitHub Calendar Interactive Container
          Div(
            className:
                'p-6 sm:p-8 rounded-2xl bg-zinc-900/40 border border-zinc-800/80 shadow-xl overflow-x-auto',
            children: [
              Div(
                className: 'flex items-center justify-between pb-6 mb-6 border-b border-zinc-800/60',
                children: [
                  Div(
                    className: 'flex items-center gap-3',
                    children: [
                      Raw(LucideIcons.svg(LucideIconName.github, className: 'w-5 h-5 text-indigo-400')),
                      Span(
                        className: 'font-mono text-sm font-semibold text-zinc-200',
                        text: 'Contribution Activity Calendar',
                      ),
                    ],
                  ),
                  Span(
                    className: 'font-mono text-xs text-zinc-500 hidden sm:inline',
                    text: 'Account: @${PortfolioPersona.githubActivityUser}',
                  ),
                ],
              ),

              // Calendar Target Container Node
              RefNode(
                _calendarRef,
                Div(
                  attrs: {'id': 'github-calendar-mount'},
                  className: 'calendar font-mono text-xs text-zinc-300 min-h-[140px] flex items-center justify-center',
                  children: [
                    Span(
                      className: 'text-zinc-500 text-xs font-mono animate-pulse',
                      text: 'Loading commit telemetry data...',
                    ),
                  ],
                ),
              ),

              // Explicit Disclaimer / Caption
              Div(
                className: 'mt-6 pt-4 border-t border-zinc-800/40 flex items-center gap-2 text-xs text-zinc-500 font-mono',
                children: [
                  Raw(LucideIcons.svg(LucideIconName.alertCircle, className: 'w-3.5 h-3.5 text-zinc-400 shrink-0')),
                  Span(
                    text:
                        'Sample open-source telemetry data for demonstration visualization. Live data rendered via github-calendar NPM package.',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      onMount: () {
        if (_calendarRef.isMounted) {
          GitHubCalendarPlugin.render(
            _calendarRef.value as web.Element,
            PortfolioPersona.githubActivityUser,
            responsive: true,
            summaryText: 'Summary of pull requests, issues, and commits',
          );
        }
      },
    );
  }

  BloomNode _metricCard(String value, String label, LucideIconName icon) {
    return Div(
      className:
          'p-5 rounded-xl bg-zinc-900/30 border border-zinc-800/60 flex flex-col gap-2',
      children: [
        Div(
          className: 'flex items-center justify-between text-zinc-500',
          children: [
            Span(className: 'text-xs font-mono text-zinc-400', text: label),
            Raw(LucideIcons.svg(icon, className: 'w-4 h-4 text-indigo-400/70')),
          ],
        ),
        Span(
          className: 'text-2xl sm:text-3xl font-extrabold font-mono text-zinc-100 tracking-tight',
          text: value,
        ),
      ],
    );
  }
}
