// lib/src/commands/ui_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Parent command to manage and add Bloom UI primitives (shadcn-inspired Flutter UI library).
///
/// Provides subcommands: `add`, `list`, and `init`.
///
/// Example:
/// ```
/// bloom ui list
/// bloom ui init
/// bloom ui add button
/// bloom ui add all --overwrite
/// ```
class UiCommand extends Command<int> {
  @override
  final String name = 'ui';
  @override
  final String description = 'Manage and add Bloom UI primitives (shadcn-inspired Flutter UI library).';

  UiCommand() {
    addSubcommand(UiAddCommand());
    addSubcommand(UiListCommand());
    addSubcommand(UiInitCommand());
  }

  @override
  Future<int> run() async {
    printUsage();
    return 0;
  }
}

/// Subcommand that lists all available Bloom UI primitives grouped by category.
///
/// Example:
/// ```
/// bloom ui list
/// ```
class UiListCommand extends Command<int> {
  @override
  final String name = 'list';
  @override
  final String description = 'Lists all available Bloom UI primitives.';

  @override
  Future<int> run() async {
    print(Ansi.boldText('\n🌸 Bloom UI Primitives Registry\n'));

    final primitives = _getPrimitivesList();
    for (final category in primitives.keys) {
      print(Ansi.boldText('${Ansi.magenta}$category${Ansi.reset}'));
      for (final item in primitives[category]!) {
        print('  • ${Ansi.cyan}${item.name.padRight(20)}${Ansi.reset} ${item.description}');
      }
      print('');
    }
    print(Ansi.dimText('Use "bloom ui add <primitive>" to copy a primitive into your project.'));
    print(Ansi.dimText('Use "bloom ui add all" to install the entire component suite.\n'));
    return 0;
  }
}

/// Subcommand that adds a Bloom UI primitive to your project via copy-paste architecture.
///
/// Example:
/// ```
/// bloom ui add button
/// bloom ui add dialog --overwrite
/// bloom ui add all
/// ```
class UiAddCommand extends Command<int> {
  @override
  final String name = 'add';
  @override
  final String description = 'Adds a Bloom UI primitive to your project (copy-paste architecture).';

  UiAddCommand() {
    argParser.addFlag(
      'overwrite',
      abbr: 'o',
      defaultsTo: false,
      help: 'Overwrite existing files if already present.',
    );
  }

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a primitive name or "all" (e.g. "bloom ui add button").'));
      return 1;
    }

    final target = rest.first.trim().toLowerCase();
    final project = BloomProject.find();
    final targetDir = project != null
        ? Directory(p.join(project.rootDir.path, 'lib', 'bloom_ui'))
        : Directory(p.join(Directory.current.path, 'lib', 'bloom_ui'));

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    // Source primitives directory in packages/bloom_ui
    final candidates = [
      p.join(Directory.current.path, 'packages', 'bloom_ui', 'lib'),
      '/root/dev/Bloom/packages/bloom_ui/lib',
    ];

    Directory? sourceDir;
    for (final c in candidates) {
      final d = Directory(c);
      if (d.existsSync()) {
        sourceDir = d;
        break;
      }
    }

    if (sourceDir == null) {
      print(Ansi.error('Could not locate bloom_ui source package templates.'));
      return 1;
    }

    final overwrite = argResults?['overwrite'] as bool? ?? false;

    if (target == 'all') {
      print(Ansi.boldText('\n🌸 Installing all Bloom UI primitives and design tokens...\n'));
      _copyDirectory(sourceDir, targetDir, overwrite);
      print(Ansi.success('All Bloom UI components installed to ${targetDir.path}\n'));
      return 0;
    }

    // Single primitive copy
    final primitiveFile = File(p.join(sourceDir.path, 'src', 'primitives', '$target.dart'));
    if (!primitiveFile.existsSync()) {
      print(Ansi.error('Primitive "$target" not found in Bloom UI registry.'));
      print(Ansi.info('Run "bloom ui list" to see all available primitives.'));
      return 1;
    }

    // Ensure theme and utils exist in target project
    final themeSource = Directory(p.join(sourceDir.path, 'src', 'theme'));
    final utilsSource = Directory(p.join(sourceDir.path, 'src', 'utils'));
    final destTheme = Directory(p.join(targetDir.path, 'src', 'theme'));
    final destUtils = Directory(p.join(targetDir.path, 'src', 'utils'));

    if (!destTheme.existsSync()) _copyDirectory(themeSource, destTheme, false);
    if (!destUtils.existsSync()) _copyDirectory(utilsSource, destUtils, false);

    final destPrimitives = Directory(p.join(targetDir.path, 'src', 'primitives'));
    if (!destPrimitives.existsSync()) destPrimitives.createSync(recursive: true);

    final destFile = File(p.join(destPrimitives.path, '$target.dart'));
    if (destFile.existsSync() && !overwrite) {
      print(Ansi.warn('File already exists: ${destFile.path}. Use --overwrite to replace.'));
      return 0;
    }

    destFile.writeAsStringSync(primitiveFile.readAsStringSync());
    print(Ansi.success('Added Bloom UI primitive: ${Ansi.cyan}$target${Ansi.reset} -> ${destFile.path}'));
    return 0;
  }

  void _copyDirectory(Directory source, Directory destination, bool overwrite) {
    if (!destination.existsSync()) destination.createSync(recursive: true);
    for (final entity in source.listSync(recursive: true)) {
      if (entity is File) {
        final rel = p.relative(entity.path, from: source.path);
        final dest = File(p.join(destination.path, rel));
        if (!dest.parent.existsSync()) dest.parent.createSync(recursive: true);
        if (!dest.existsSync() || overwrite) {
          dest.writeAsStringSync(entity.readAsStringSync());
        }
      }
    }
  }
}

/// Subcommand that initializes Bloom UI design tokens and theme configuration in your project.
///
/// Example:
/// ```
/// bloom ui init
/// ```
class UiInitCommand extends Command<int> {
  @override
  final String name = 'init';
  @override
  final String description = 'Initializes Bloom UI design tokens and theme configuration in your project.';

  @override
  Future<int> run() async {
    print(Ansi.boldText('\n🌸 Initializing Bloom UI design tokens & theme...\n'));
    final project = BloomProject.find();
    final targetDir = project != null
        ? Directory(p.join(project.rootDir.path, 'lib', 'bloom_ui'))
        : Directory(p.join(Directory.current.path, 'lib', 'bloom_ui'));

    final candidates = [
      p.join(Directory.current.path, 'packages', 'bloom_ui', 'lib'),
      '/root/dev/Bloom/packages/bloom_ui/lib',
    ];

    Directory? sourceDir;
    for (final c in candidates) {
      final d = Directory(c);
      if (d.existsSync()) {
        sourceDir = d;
        break;
      }
    }

    if (sourceDir == null) {
      print(Ansi.error('Could not locate bloom_ui template files.'));
      return 1;
    }

    // Copy theme & utils
    final themeSource = Directory(p.join(sourceDir.path, 'src', 'theme'));
    final utilsSource = Directory(p.join(sourceDir.path, 'src', 'utils'));
    final destTheme = Directory(p.join(targetDir.path, 'src', 'theme'));
    final destUtils = Directory(p.join(targetDir.path, 'src', 'utils'));

    if (!destTheme.existsSync()) destTheme.createSync(recursive: true);
    if (!destUtils.existsSync()) destUtils.createSync(recursive: true);

    for (final f in themeSource.listSync()) {
      if (f is File) File(p.join(destTheme.path, p.basename(f.path))).writeAsStringSync(f.readAsStringSync());
    }
    for (final f in utilsSource.listSync()) {
      if (f is File) File(p.join(destUtils.path, p.basename(f.path))).writeAsStringSync(f.readAsStringSync());
    }

    print(Ansi.success('Bloom UI design system initialized in ${targetDir.path}'));
    print(Ansi.info('You can now add primitives using "bloom ui add <name>".\n'));
    return 0;
  }
}

class _PrimitiveMeta {
  final String name;
  final String description;
  const _PrimitiveMeta(this.name, this.description);
}

Map<String, List<_PrimitiveMeta>> _getPrimitivesList() {
  return {
    'Form Controls': [
      const _PrimitiveMeta('button', 'Interactive button with 6 variants, sizes & loading states'),
      const _PrimitiveMeta('button_group', 'Grouped button container with horizontal/vertical orientation'),
      const _PrimitiveMeta('input', 'Clean text input field with error & label support'),
      const _PrimitiveMeta('input_group', 'Composed input with leading/trailing addons and icons'),
      const _PrimitiveMeta('input_otp', 'Accessible segmented OTP digit code input'),
      const _PrimitiveMeta('textarea', 'Multi-line expanded text area with auto-resize'),
      const _PrimitiveMeta('checkbox', 'Checkbox with custom checkmark animation'),
      const _PrimitiveMeta('radio', 'Radio buttons and RadioGroup selection'),
      const _PrimitiveMeta('switch', 'Toggle switch with smooth spring animation'),
      const _PrimitiveMeta('slider', 'Continuous range slider control'),
      const _PrimitiveMeta('select', 'Dropdown select picker with item mapping'),
      const _PrimitiveMeta('native_select', 'Native platform select dropdown'),
      const _PrimitiveMeta('combobox', 'Searchable combobox with autocomplete dropdown'),
      const _PrimitiveMeta('toggle', 'Two-state toggle button and toggle groups'),
      const _PrimitiveMeta('calendar', 'Single, multi-date and range calendar picker'),
      const _PrimitiveMeta('field', 'Accessible form field wrapper with error, label & description'),
      const _PrimitiveMeta('form', 'Form validation state container'),
    ],
    'Layout & Containers': [
      const _PrimitiveMeta('accordion', 'Collapsible multi-section accordion panel'),
      const _PrimitiveMeta('collapsible', 'Expandable/collapsible content drawer'),
      const _PrimitiveMeta('tabs', 'Tabbed interface container with animated underline'),
      const _PrimitiveMeta('separator', 'Horizontal or vertical content divider'),
      const _PrimitiveMeta('scroll_area', 'Custom smooth scroll container with themed scrollbars'),
      const _PrimitiveMeta('resizable', 'Resizable multi-panel split view layout'),
      const _PrimitiveMeta('aspect_ratio', 'Constrained aspect-ratio container'),
      const _PrimitiveMeta('skeleton', 'Animated shimmering skeleton loader'),
      const _PrimitiveMeta('progress', 'Linear progress bar with indeterminate animation'),
      const _PrimitiveMeta('spinner', 'Circular activity loading spinner'),
    ],
    'Feedback & Notifications': [
      const _PrimitiveMeta('alert', 'Contextual status banner with 5 variants'),
      const _PrimitiveMeta('alert_dialog', 'Modal confirmation dialog requiring user response'),
      const _PrimitiveMeta('dialog', 'Modal dialog container with header and actions'),
      const _PrimitiveMeta('toast', 'Lightweight floating notification'),
      const _PrimitiveMeta('sonner', 'Opinionated toast system with success, error, info, promise'),
      const _PrimitiveMeta('banner', 'Persistent top/bottom announcement banner'),
    ],
    'Overlays & Popups': [
      const _PrimitiveMeta('sheet', 'Sliding side and bottom sheet overlay'),
      const _PrimitiveMeta('drawer', 'Platform slide-out navigation drawer'),
      const _PrimitiveMeta('popover', 'Anchored popover container floating over trigger'),
      const _PrimitiveMeta('tooltip', 'Hover/tap informative tooltip text'),
      const _PrimitiveMeta('hover_card', 'Rich preview popover displayed on hover/tap'),
      const _PrimitiveMeta('dropdown_menu', 'Contextual dropdown menu list'),
      const _PrimitiveMeta('context_menu', 'Secondary click / long press context menu'),
      const _PrimitiveMeta('menubar', 'Desktop-style top application menubar hierarchy'),
    ],
    'Data Display & Analytics': [
      const _PrimitiveMeta('avatar', 'Image and fallback monogram user avatar'),
      const _PrimitiveMeta('badge', 'Status badge pill with multiple styles'),
      const _PrimitiveMeta('card', 'Structured container with title, description, content, footer'),
      const _PrimitiveMeta('table', 'Structured data table with styled cells and header'),
      const _PrimitiveMeta('data_table', 'Generic typed data table with column builders'),
      const _PrimitiveMeta('pagination', 'Page number navigation with previous/next buttons'),
      const _PrimitiveMeta('breadcrumb', 'Hierarchical path navigation trail'),
      const _PrimitiveMeta('navigation_menu', 'Navigation destination bar'),
      const _PrimitiveMeta('sidebar', 'Expandable navigation rail / sidebar layout'),
      const _PrimitiveMeta('carousel', 'Swipeable multi-slide carousel with indicator dots'),
      const _PrimitiveMeta('chart', 'Pure Dart charts: Area, Bar, Line, Pie, Radar, Radial'),
      const _PrimitiveMeta('kbd', 'Styled keyboard shortcut indicator key'),
      const _PrimitiveMeta('marker', 'Highlighted marker badge and inline tag'),
      const _PrimitiveMeta('empty', 'Empty state placeholder container with title and action'),
      const _PrimitiveMeta('item', 'Versatile list item tile with slots for icons and actions'),
      const _PrimitiveMeta('typography', 'Typography hierarchy text components'),
    ],
    'AI & Chat Interface': [
      const _PrimitiveMeta('message', 'AI chat bubble with role, avatar, and content'),
      const _PrimitiveMeta('bubble', 'Stylized message speech bubble'),
      const _PrimitiveMeta('attachment', 'File/image attachment chip with progress & remove action'),
      const _PrimitiveMeta('message_scroller', 'Auto-scrolling chat history viewport'),
      const _PrimitiveMeta('questionnaire', 'Multi-step conversational wizard & quiz container'),
    ],
    'Composites & Shells': [
      const _PrimitiveMeta('command_palette', 'Searchable command palette dialog with keyboard navigation'),
      const _PrimitiveMeta('multi_select', 'Multi-tag selector dropdown with chip removal'),
      const _PrimitiveMeta('tags_input', 'Interactive chip tag entry field'),
      const _PrimitiveMeta('phone_input', 'International phone number input with country code'),
      const _PrimitiveMeta('search_bar', 'Search bar with clear action and live query callbacks'),
      const _PrimitiveMeta('filter_bar', 'Horizontal scrollable filter chip bar'),
      const _PrimitiveMeta('settings_list', 'iOS/macOS style grouped settings section list'),
      const _PrimitiveMeta('pricing_card', 'SaaS pricing plan card with feature checklist & popular badge'),
      const _PrimitiveMeta('auth_form', 'Authentication login/signup card with remember-me & error banner'),
      const _PrimitiveMeta('app_shell', 'Complete responsive application scaffold & dashboard shell'),
    ],
  };
}
