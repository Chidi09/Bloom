// bin/bloom.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../lib/src/commands/add_command.dart';
import '../lib/src/commands/analyze_command.dart';
import '../lib/src/commands/autolink_command.dart';
import '../lib/src/commands/build_command.dart';
import '../lib/src/commands/create_command.dart';
import '../lib/src/commands/create_module_command.dart';
import '../lib/src/commands/deploy_command.dart';
import '../lib/src/commands/deps_command.dart';
import '../lib/src/commands/dev_command.dart';
import '../lib/src/commands/doctor_command.dart';
import '../lib/src/commands/generate_command.dart';
import '../lib/src/commands/prebuild_command.dart';
import '../lib/src/commands/remove_command.dart';
import '../lib/src/commands/test_command.dart';
import '../lib/src/commands/why_command.dart';
import '../lib/src/commands/workspace_command.dart';
import '../lib/src/utils/ansi.dart';

const String bloomVersion = '0.1.0';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>(
    'bloom',
    'Bloom: The Opinionated Application Framework & Developer Platform for Flutter.',
  )
    ..addCommand(CreateCommand())
    ..addCommand(CreateModuleCommand())
    ..addCommand(AutolinkCommand())
    ..addCommand(DepsCommand())
    ..addCommand(WhyCommand())
    ..addCommand(WorkspaceCommand())
    ..addCommand(DevCommand())
    ..addCommand(DoctorCommand())
    ..addCommand(GenerateCommand())
    ..addCommand(AnalyzeCommand())
    ..addCommand(TestCommand())
    ..addCommand(BuildCommand())
    ..addCommand(PrebuildCommand())
    ..addCommand(AddCommand())
    ..addCommand(RemoveCommand())
    ..addCommand(DeployCommand());

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
