// lib/src/commands/templates_command.dart
import 'dart:convert';
import 'package:args/command_runner.dart';
import '../templates/template_registry.dart';
import '../utils/ansi.dart';

class TemplatesCommand extends Command<int> {
  @override
  final String name = 'templates';

  @override
  final String description = 'Search and list official and community Bloom starter templates.';

  TemplatesCommand() {
    argParser.addFlag(
      'json',
      help: 'Output template registry in machine-readable JSON format.',
      defaultsTo: false,
    );
  }

  @override
  Future<int> run() async {
    final asJson = argResults?['json'] == true;

    if (asJson) {
      final jsonList = TemplateRegistry.officialTemplates.map((t) => {
            'name': t.name,
            'description': t.description,
            'category': t.category,
            'features': t.includedFeatures,
          }).toList();
      print(const JsonEncoder.withIndent('  ').convert(jsonList));
      return 0;
    }

    print(Ansi.boldText('\n📦 Available Bloom Starter Templates:\n'));

    for (final template in TemplateRegistry.officialTemplates) {
      print('  • ${Ansi.cyan}${template.name}${Ansi.reset} [${template.category}]');
      print('    ${template.description}');
      print('    Features: ${template.includedFeatures.join(', ')}\n');
    }

    print(Ansi.dimText('To create a project using a template:'));
    print('  bloom create <project_name> --template <template_name>');
    print('  bloom create <project_name> --template github:<org>/<repo>\n');

    return 0;
  }
}
