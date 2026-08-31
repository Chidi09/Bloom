import 'package:bloom_js_native/bloom_js_native.dart';
import '../components/hero_video_bg.dart';
import '../components/huge_icons.dart';
import '../components/interactive/enterprise_ota_topology.dart';
import '../components/interactive/ota_release_playground.dart';
import '../components/interactive/programmatic_update_explorer.dart';
import '../components/interactive/vercel_ship_dashboard.dart';
import '../components/interactive/wireless_qr_visualizer.dart';
import 'page_layout.dart';

BloomNode shipPage() {
  return pageLayout(
    currentPath: '/ship',
    petalHighlight: 'blue',
    nextChapterTitle: 'BLOOM — UI Studio & Tokens',
    nextChapterLink: '/bloom',
    nextChapterSubtitle:
        'Customize design tokens, color swatches, radii, and preview '
        'production-ready Flutter components.',
    child: Div(
      className: 'relative space-y-24 pb-20',
      children: [
        // 1. Hero Section
        Section(
          className:
              'pt-16 pb-16 lg:pt-24 lg:pb-20 relative overflow-hidden '
              'text-center',
          children: [
            heroVideoBg(mode: 'ship'),
            Div(
              className: 'max-w-4xl mx-auto space-y-6 relative z-10 px-4',
              children: [
                // Vercel/Linear Status Badge
                Div(
                  className:
                      'inline-flex items-center gap-2.5 px-3.5 py-1.5 '
                      'rounded-full bg-slate-900/90 dark:bg-black/90 border '
                      'border-slate-700/60 dark:border-zinc-800 text-xs font-mono '
                      'text-slate-300 shadow-md',
                  children: [
                    Span(
                      className: 'flex h-2 w-2 relative shrink-0',
                      children: [
                        Span(
                          className:
                              'animate-ping absolute inline-flex h-full w-full '
                              'rounded-full bg-slate-400 opacity-75',
                        ),
                        Span(
                          className:
                              'relative inline-flex rounded-full h-2 w-2 bg-slate-500',
                        ),
                      ],
                    ),
                    Span(
                      className: 'font-semibold text-slate-200',
                      text: 'CHAPTER 02',
                    ),
                    Span(
                      className: 'text-slate-600 dark:text-slate-500',
                      text: '•',
                    ),
                    Span(
                      className: 'text-slate-400 dark:text-slate-400 font-mono',
                      text: 'OTA_DEPLOY_PIPELINE',
                    ),
                  ],
                ),
                H1(
                  className:
                      'text-4xl sm:text-6xl lg:text-7xl font-black '
                      'tracking-tight text-slate-900 dark:text-white '
                      'leading-[1.05]',
                  children: [
                    const Text('Ship instantly.'),
                    El('br'),
                    Span(
                      className: 'text-gradient-silver',
                      text: 'Shorebird-Powered OTA.',
                    ),
                  ],
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-xl '
                      'max-w-2xl mx-auto leading-relaxed',
                  text:
                      'Bloom Cloud compiles Dart AOT bytecode patches and '
                      'deploys directly to physical iOS & Android devices in '
                      'milliseconds—bypassing App Store queues completely.',
                ),
              ],
            ),
            Div(
              className: 'mt-12 max-w-6xl mx-auto px-4',
              children: [vercelShipDashboard()],
            ),
          ],
        ),

        // 2. Configuration & CLI Orchestration (#ship-cli)
        Section(
          attrs: const {'id': 'ship-cli'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'Declarative Release Management',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Manage deployment environments, channel promotions, and '
                      'rollout rules directly in config or via the CLI.',
                ),
              ],
            ),
            otaReleasePlayground(),
          ],
        ),

        // 3. Wireless Dev & QR Install Workflows (#dev-workflows)
        Section(
          attrs: const {'id': 'dev-workflows'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'Wireless Development & Instant QR Installs',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Eliminate tethering friction with wireless device '
                      'pairing and instant QR build previews.',
                ),
              ],
            ),
            wirelessQrVisualizer(),
          ],
        ),

        // 4. Programmatic Update API (#ota-api)
        Section(
          attrs: const {'id': 'ota-api'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'Programmatic Update API',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Manage silent background downloads, force critical '
                      'updates, and display custom download indicators.',
                ),
              ],
            ),
            programmaticUpdateExplorer(),
          ],
        ),

        // 5. Enterprise Architecture Section (#ota-architecture)
        Section(
          attrs: const {'id': 'ota-architecture'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'Enterprise-Grade OTA Architecture',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'How Bloom updates reach millions of devices securely '
                      'without app store resubmission.',
                ),
              ],
            ),
            enterpriseOtaTopology(),
          ],
        ),

        // 6. Full Platform Overview (#cloud-platform)
        Section(
          attrs: const {'id': 'cloud-platform'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 pt-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                Div(
                  className:
                      'inline-flex items-center gap-2.5 px-3.5 py-1.5 '
                      'rounded-full bg-slate-900/90 dark:bg-black/90 border '
                      'border-slate-700/60 dark:border-zinc-800 text-xs font-mono '
                      'text-slate-300 shadow-md mb-2',
                  children: [
                    Span(
                      className: 'font-semibold text-slate-200',
                      text: 'BEYOND PATCHES',
                    ),
                  ],
                ),
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'One Dashboard, The Whole Release Lifecycle',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'OTA patching is one piece. Bloom Cloud is a full '
                      'delivery platform—from source to store to your '
                      'users’ devices.',
                ),
              ],
            ),

            // 15 Glass Panels Grid
            Div(
              className: 'space-y-8 max-w-5xl mx-auto mb-8',
              children: [
                // Row 1
                Div(
                  className: 'grid grid-cols-1 md:grid-cols-3 gap-8',
                  children: [
                    _renderGlassCard(
                      icon: 'folder',
                      title: 'Organizations & Projects',
                      desc:
                          'Multi-tenant hierarchy—organizations own projects, '
                          'projects own apps. Every team, client, or product '
                          'line stays cleanly isolated.',
                    ),
                    _renderGlassCard(
                      icon: 'check-circle',
                      title: 'Role-Based Access Control',
                      desc:
                          'Owner, Admin, Developer, and Release Manager roles '
                          'gate who can approve releases, touch secrets, or '
                          'manage billing.',
                    ),
                    _renderGlassCard(
                      icon: 'code',
                      title: 'Audit Log & Compliance',
                      desc:
                          'Every build, approval, secret rotation, and rollback '
                          'is recorded in a searchable, filterable audit trail.',
                    ),
                  ],
                ),

                // Row 2
                Div(
                  className: 'grid grid-cols-1 md:grid-cols-3 gap-8',
                  children: [
                    _renderGlassCard(
                      icon: 'cpu',
                      title: 'Remote Build Farm',
                      desc:
                          'Compile iOS, Android, and Web artifacts in the '
                          'cloud—no local toolchain, no waiting on a laptop. '
                          'Live stage-by-stage logs.',
                    ),
                    _renderGlassCard(
                      icon: 'refresh',
                      title: 'Release Approvals & Rollback',
                      desc:
                          'Staged rollout percentages, gated approvals for '
                          'Release Managers, changelog diffing, and one-click '
                          'rollback to any prior version.',
                    ),
                    _renderGlassCard(
                      icon: 'zap',
                      title: 'Multi-Target Deployments',
                      desc:
                          'Ship the same release to TestFlight, Google Play, and '
                          'the Web from one pipeline—with live platform-specific '
                          'status tracking.',
                    ),
                  ],
                ),

                // Row 3
                Div(
                  className: 'grid grid-cols-1 md:grid-cols-3 gap-8',
                  children: [
                    _renderGlassCard(
                      icon: 'sparkles',
                      title: 'Environments',
                      desc:
                          'Pin SDK versions, flavors, and feature flags per '
                          'environment—production, staging, and preview stay '
                          'independently configured.',
                    ),
                    _renderGlassCard(
                      icon: 'sparkles',
                      title: 'Secrets Vault',
                      desc:
                          'Versioned, write-only secrets storage. Plaintext '
                          'values are never re-rendered after save—reveal is a '
                          'fresh, on-demand fetch.',
                    ),
                    _renderGlassCard(
                      icon: 'code',
                      title: 'Signing Identity Management',
                      desc:
                          'Keystores, certificates, provisioning profiles, and '
                          'API keys in one place, with expiry warnings before '
                          'they lapse.',
                    ),
                  ],
                ),

                // Row 4
                Div(
                  className: 'grid grid-cols-1 md:grid-cols-3 gap-8',
                  children: [
                    _renderGlassCard(
                      icon: 'folder',
                      title: 'Git Connections',
                      desc:
                          'Connect GitHub, GitLab, or Bitbucket. '
                          'Branch-to-environment deploy policies and full '
                          'webhook delivery logs with replay.',
                    ),
                    _renderGlassCard(
                      icon: 'server',
                      title: 'Web Hosting & Custom Domains',
                      desc:
                          'Host your Flutter Web build directly. Add custom '
                          'domains with copy-paste DNS records and automatic '
                          'SSL verification.',
                    ),
                    _renderGlassCard(
                      icon: 'zap',
                      title: 'Observability',
                      desc:
                          'Release health, crash-free rate, and deployment '
                          'status in real time—know a rollout is unhealthy '
                          'before your users complain.',
                    ),
                  ],
                ),

                // Row 5
                Div(
                  className: 'grid grid-cols-1 md:grid-cols-3 gap-8',
                  children: [
                    _renderGlassCard(
                      icon: 'refresh',
                      title: 'Workflow Automation',
                      desc:
                          'Custom pipelines with triggers and approval '
                          'gates—chain builds, tests, and deployments into a '
                          'repeatable release process.',
                    ),
                    _renderGlassCard(
                      icon: 'sparkles',
                      title: 'Template Marketplace',
                      desc:
                          'Buy production-ready app templates or publish your '
                          'own with seller payouts—versioned, reviewed, and '
                          'ready to fork.',
                    ),
                    _renderGlassCard(
                      icon: 'sparkles',
                      title: 'Team & Billing',
                      desc:
                          'Usage-based plans, itemized invoices, and seat '
                          'management scoped per organization—no surprise '
                          'overages.',
                    ),
                  ],
                ),
              ],
            ),

            // Bottom CTA Buttons
            Div(
              className:
                  'flex flex-col sm:flex-row items-center justify-center gap-4 '
                  'pt-12',
              children: [
                A(
                  href: 'https://cloud.bloom.dev',
                  attrs: const {'target': '_blank'},
                  className:
                      'inline-flex items-center gap-2 px-6 py-3.5 rounded-2xl '
                      'bg-slate-900 dark:bg-white text-white dark:text-slate-900 '
                      'font-bold text-sm hover:opacity-90 transition shadow-lg',
                  children: [
                    const Text('Open Cloud Dashboard'),
                    hugeIcon('arrow-right', className: 'w-4 h-4'),
                  ],
                ),
                A(
                  href: '/build',
                  className:
                      'inline-flex items-center gap-2 px-6 py-3.5 rounded-2xl '
                      'bg-slate-100 dark:bg-zinc-900 text-slate-900 '
                      'dark:text-white font-bold text-sm hover:bg-slate-200 '
                      'dark:hover:bg-zinc-800 transition',
                  children: [
                    const Text('Read the Platform Docs'),
                    hugeIcon('arrow-right', className: 'w-4 h-4'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

BloomNode _renderGlassCard({
  required String icon,
  required String title,
  required String desc,
}) {
  return Div(
    className:
        'p-8 rounded-3xl glass-panel border border-slate-200/80 '
        'dark:border-zinc-800 transition duration-300 hover:border-purple-500/40 '
        'text-left space-y-3',
    children: [
      hugeIcon(
        icon,
        className: 'w-8 h-8 text-slate-500 dark:text-slate-400 mb-4',
      ),
      H3(
        className: 'text-xl font-bold text-slate-900 dark:text-white mb-2',
        text: title,
      ),
      P(
        className:
            'text-xs text-slate-600 dark:text-slate-400 '
            'leading-relaxed font-sans',
        text: desc,
      ),
    ],
  );
}
