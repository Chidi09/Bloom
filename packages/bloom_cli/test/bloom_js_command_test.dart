import 'package:bloom_cli/src/commands/js_command.dart';
import 'package:test/test.dart';

void main() {
  group('JsCommand', () {
    test('registers dev, build, and vendor subcommands', () {
      final cmd = JsCommand();
      expect(cmd.name, 'js');
      expect(cmd.subcommands.keys, containsAll(['dev', 'build', 'vendor']));
    });

    test('JsBuildCommand supports --analyze flag', () {
      final cmd = JsBuildCommand();
      expect(cmd.argParser.options.containsKey('analyze'), isTrue);
      expect(cmd.argParser.options.containsKey('output'), isTrue);
    });

    test('JsDevCommand supports --port and --entry options', () {
      final cmd = JsDevCommand();
      expect(cmd.argParser.options.containsKey('port'), isTrue);
      expect(cmd.argParser.options.containsKey('entry'), isTrue);
    });
  });
}
