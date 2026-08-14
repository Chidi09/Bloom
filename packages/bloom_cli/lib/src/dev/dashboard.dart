// lib/src/dev/dashboard.dart
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'dev_server.dart';
import 'qr_renderer.dart';

class DevDashboard {
  final BloomProject project;
  final BloomDevServer devServer;
  final String? flavor;
  bool showQrCode = true;

  DevDashboard({
    required this.project,
    required this.devServer,
    this.flavor,
  });

  /// Render the full developer terminal dashboard.
  void render() {
    print(Ansi.boldText('\n🌸 ══════════════════════════════════════════════════════ 🌸'));
    print(Ansi.boldText('   BLOOM DEVELOPMENT ENGINE  •  ACTIVE SESSION'));
    print(Ansi.boldText('🌸 ══════════════════════════════════════════════════════ 🌸\n'));

    print('  ${Ansi.boldText('Project:')}      ${project.projectName}');
    if (flavor != null) {
      print('  ${Ansi.boldText('Flavor:')}       ${Ansi.cyan}$flavor${Ansi.reset}');
    }
    print('  ${Ansi.boldText('Local Server:')} ${Ansi.green}${devServer.httpUrl}${Ansi.reset}');
    print('  ${Ansi.boldText('Pairing URI:')}  ${Ansi.cyan}${devServer.devServerUri}${Ansi.reset}');
    print('  ${Ansi.boldText('Connected:')}    ${devServer.pairedDevices.isEmpty ? '0 wireless devices' : '${devServer.pairedDevices.length} device(s)'}');

    if (showQrCode) {
      print('\n  ${Ansi.boldText('Scan with Bloom Go to launch wirelessly on physical device:')}\n');
      final qr = QrTerminalRenderer.render(devServer.devServerUri);
      print(qr);
    }

    final routes = project.scanRoutes();
    print('  ${Ansi.boldText('Routes (${routes.length}):')}');
    for (final r in routes) {
      print('    ${Ansi.cyan}•${Ansi.reset} ${r.routePath.padRight(20)} ${Ansi.dim}(${r.relativeFilePath})${Ansi.reset}');
    }

    print('\n${Ansi.boldText('  Developer Shortcuts:')}');
    print('    ${Ansi.yellow}r${Ansi.reset} Hot reload           ${Ansi.yellow}R${Ansi.reset} Hot restart');
    print('    ${Ansi.yellow}w${Ansi.reset} Toggle QR code       ${Ansi.yellow}d${Ansi.reset} Paired devices');
    print('    ${Ansi.yellow}o${Ansi.reset} Open browser         ${Ansi.yellow}c${Ansi.reset} Clear console');
    print('    ${Ansi.yellow}q${Ansi.reset} Quit dev session\n');
  }

  /// Print paired wireless devices.
  void printDevices() {
    if (devServer.pairedDevices.isEmpty) {
      print(Ansi.info('\n📱 No wireless devices currently connected. Scan the QR code with Bloom Go to pair.\n'));
      return;
    }

    print(Ansi.boldText('\n📱 Paired Wireless Devices:'));
    for (final d in devServer.pairedDevices) {
      print('  • ${Ansi.green}${d['name']}${Ansi.reset} (${d['os']} ${d['model']}) - Paired at ${d['pairedAt']}');
    }
    print('');
  }
}
