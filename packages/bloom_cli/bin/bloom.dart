// bin/bloom.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../lib/src/commands/add_command.dart';
import '../lib/src/commands/analyze_command.dart';
import '../lib/src/commands/assets_command.dart';
import '../lib/src/commands/audit_command.dart';
import '../lib/src/commands/autolink_command.dart';
import '../lib/src/commands/build_command.dart';
import '../lib/src/commands/create_command.dart';
import '../lib/src/commands/create_module_command.dart';
import '../lib/src/commands/deploy_command.dart';
import '../lib/src/commands/deps_command.dart';
import '../lib/src/commands/dev_command.dart';
import '../lib/src/commands/doctor_command.dart';
import '../lib/src/commands/explain_command.dart';
import '../lib/src/commands/font_command.dart';
import '../lib/src/commands/format_command.dart';
import '../lib/src/commands/generate_command.dart';
import '../lib/src/commands/graph_command.dart';
import '../lib/src/commands/insights_command.dart';
import '../lib/src/commands/js_command.dart';
import '../lib/src/commands/lint_command.dart';
import '../lib/src/commands/migrate_command.dart';
import '../lib/src/commands/module_command.dart';
import '../lib/src/commands/npm_command.dart';
import '../lib/src/commands/og_command.dart';
import '../lib/src/commands/prebuild_command.dart';
import '../lib/src/commands/registry_command.dart';
import '../lib/src/commands/remove_command.dart';
import '../lib/src/commands/security_command.dart';
import '../lib/src/commands/server_command.dart';
import '../lib/src/commands/symbols_command.dart';
import '../lib/src/commands/templates_command.dart';
import '../lib/src/commands/test_command.dart';
import '../lib/src/commands/typegen_command.dart';
import '../lib/src/commands/ui_command.dart';
import '../lib/src/commands/update_command.dart';
import '../lib/src/commands/upgrade_command.dart';
import '../lib/src/commands/why_command.dart';
import '../lib/src/commands/workspace_command.dart';
import '../lib/src/utils/ansi.dart';

// Must match the `version:` field in pubspec.yaml — this is compiled into
// the executable snapshot, so it cannot be read from pubspec.yaml at
// runtime once `dart pub global activate` has installed it. Bump this on
// every release alongside pubspec.yaml.
const String bloomVersion = '0.7.5';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>(
    'bloom',
    'Bloom: The Opinionated Application Framework & Developer Platform for Flutter.',
  )
    ..addCommand(CreateCommand())
    ..addCommand(CreateModuleCommand())
    ..addCommand(ModuleCommand())
    ..addCommand(TemplatesCommand())
    ..addCommand(RegistryCommand())
    ..addCommand(UpgradeCommand())
    ..addCommand(ExplainCommand())
    ..addCommand(GraphCommand())
    ..addCommand(AutolinkCommand())
    ..addCommand(DepsCommand())
    ..addCommand(WhyCommand())
    ..addCommand(WorkspaceCommand())
    ..addCommand(UpdateCommand())
    ..addCommand(SymbolsCommand())
    ..addCommand(AssetsCommand())
    ..addCommand(FontCommand())
    ..addCommand(OgCommand())
    ..addCommand(AuditCommand())
    ..addCommand(SecurityCommand())
    ..addCommand(DevCommand())
    ..addCommand(DoctorCommand())
    ..addCommand(InsightsCommand())
    ..addCommand(GenerateCommand())
    ..addCommand(AnalyzeCommand())
    ..addCommand(FormatCommand())
    ..addCommand(LintCommand())
    ..addCommand(TestCommand())
    ..addCommand(BuildCommand())
    ..addCommand(PrebuildCommand())
    ..addCommand(NpmCommand())
    ..addCommand(JsCommand())
    ..addCommand(AddCommand())
    ..addCommand(RemoveCommand())
    ..addCommand(TypegenCommand())
    ..addCommand(UiCommand())
    ..addCommand(DeployCommand())
    ..addCommand(MigrateCommand())
    ..addCommand(ServerCommand());

  runner.argParser.addFlag(
    'version',
    abbr: 'v',
    negatable: false,
    help: 'Prints current Bloom CLI version.',
  );

  if (args.contains('--version') || args.contains('-v')) {
    print('Bloom CLI version $bloomVersion');
    exit(0);
  }

  if (args.isEmpty) {
    printBloomBanner(version: bloomVersion);
    runner.printUsage();
    exit(0);
  }

  try {
    final exitCode = await runner.run(args);
    exit(exitCode ?? 0);
  } on UsageException catch (e) {
    print(Ansi.error(e.message));
    print('');
    print(e.usage);
    exit(64);
  } catch (e, st) {
    print(Ansi.error('Unexpected error: $e'));
    print(st);
    exit(1);
  }
}
