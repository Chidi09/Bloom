// lib/src/dev/js_dashboard.dart
import 'dart:core';

import '../utils/ansi.dart';
import '../utils/project.dart';
import 'dev_proxy.dart';

/// Next.js-style terminal dashboard for `bloom js dev`.
///
/// Renders a structured, color-coded panel once at startup (project, server
/// URL, compile mode, assets, routes, proxies, watch roots, shortcuts) — giving
/// the flat ad-hoc startup prints a hierarchy and at-a-glance build/route/proxy
/// state — and then prints compact live build-status lines as the source
/// watcher recompiles and rebroadcasts, tracking a running compile count and an
/// error count so the session state is visible at a glance.
class JsDevDashboard {
  final BloomProject project;
  final String displayHost;
  final int port;
  final bool isDdcMode;
  final List<BloomDevProxyRule> proxyRules;
  final String webDirPath;
  final String watchDirPath;

  int _compiles = 0;
  int _errors = 0;
  Stopwatch? _active;
  String _lastMode;

  JsDevDashboard({
    required this.project,
    required this.displayHost,
    required this.port,
    required this.isDdcMode,
    this.proxyRules = const [],
    required this.webDirPath,
    required this.watchDirPath,
  }) : _lastMode = isDdcMode ? 'DDC' : 'dart2js';

  /// Total successful compiles in this session.
  int get compiles => _compiles;

  /// Total failed compiles in this session.
  int get errors => _errors;

  /// Current compile mode badge.
  String get _modeBadge {
    final label = isDdcMode ? 'DDC fast dev-loop' : 'dart2js -O0';
    final color = isDdcMode ? Ansi.green : Ansi.yellow;
    return Ansi.colorize('⚡ $label', color);
  }

  /// Displays the local URL with a browser-friendly host.
  String get localUrl => 'http://$displayHost:$port';

  /// Renders the full startup dashboard panel.
  void renderStartup() {
    print(Ansi.boldText(
        '\n🌸 ══════════════════════════════════════════════════════ 🌸'));
    final subtitle = isDdcMode ? 'Fast dev-loop' : 'dart2js -O0';
    print(Ansi.boldText('   BLOOM JS DEV  ${Ansi.dimText('•  $subtitle')}'));
    print(Ansi.boldText(
        '🌸 ══════════════════════════════════════════════════════ 🌸\n'));

    _row('Project', project.projectName);
    _row('Local', Ansi.green + localUrl + Ansi.reset);
    _row('Mode', _modeBadge);
    _row('Assets', Ansi.dimText(webDirPath));
    _row('Watch', Ansi.dimText(watchDirPath));

    if (proxyRules.isNotEmpty) {
      print('  ${Ansi.boldText('Proxy (${proxyRules.length}):')}');
      for (final rule in proxyRules) {
        final stripNote = rule.stripPrefix ? ' (strip prefix)' : '';
        print('    ${Ansi.cyan}•${Ansi.reset} '
            '${rule.pathPrefix.padRight(24)} ➔ ${rule.targetUri}$stripNote');
      }
    }

    final routes = project.scanRoutes();
    print('  ${Ansi.boldText('Routes (${routes.length}):')}');
    if (routes.isEmpty) {
      print('    ${Ansi.dimText('(none yet — create lib/routes/*.dart)')}');
    } else {
      for (final r in routes) {
        print('    ${Ansi.cyan}•${Ansi.reset} '
            '${r.routePath.padRight(20)} ${Ansi.dimText(r.relativeFilePath)}${Ansi.reset}');
      }
    }

    print('  ${Ansi.boldText('Live-Reload:')}   SSE channel on /_bloom_hr • '
        'auto-inject ${isDdcMode ? 'DDC remount' : 'full reload'}');
    print('\n${Ansi.boldText('  Shortcuts:')}');
    print('    ${Ansi.yellow}Ctrl+C${Ansi.reset} Stop dev session\n');
  }

  /// Prints a labeled key/value row.
  void _row(String label, String value) {
    print('  ${Ansi.boldText('${label.padRight(7)}')} $value');
  }

  /// Called when a rebuild begins for [reason] (the changed file name).
  void onBuildStart(String reason) {
    _active = Stopwatch()..start();
    print('${Ansi.step('compiling $reason')}  '
        '${Ansi.dimText('[$_lastMode]')}');
  }

  /// Called when a rebuild completes.
  ///
  /// Prints a compact live status line with the elapsed time, a running
  /// compile/error count and the current mode. [note] briefly describes the
  /// outcome (e.g. `'Hot Remount'`, `'Hot Reload'`, `'CSS Hot Swap'`).
  void onBuildFinished(bool success, {String? note, String? errorText}) {
    final elapsed = _active;
    int ms = 0;
    if (elapsed != null) {
      elapsed.stop();
      ms = elapsed.elapsed.inMilliseconds;
    }
    _active = null;

    if (success) {
      _compiles++;
      final label = note ?? 'build ok';
      final line =
          '  ${Ansi.green}✔${Ansi.reset} $label in ${_fmtMs(ms)}  '
          '${Ansi.dimText('($_compiles builds, $_errors errors) [$_lastMode]')}';
      print(line);
    } else {
      _errors++;
      _lastMode = isDdcMode ? 'DDC' : 'dart2js';
      print(
          '  ${Ansi.red}✖${Ansi.reset} build failed in ${_fmtMs(ms)}  '
          '${Ansi.dimText('($_compiles builds, $_errors errors) [$_lastMode]')}');
      if (errorText != null && errorText.trim().isNotEmpty) {
        print(
            '    ${Ansi.dimText(errorText.trim().split('\n').first)}${Ansi.reset}');
      }
    }
  }

  static String _fmtMs(int ms) {
    return ms >= 1000
        ? '${(ms / 1000).toStringAsFixed(2)}s'
        : '$ms ms';
  }
}