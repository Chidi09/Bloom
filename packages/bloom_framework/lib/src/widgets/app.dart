/// Root application widget for Bloom Flutter applications.
library;

import 'package:flutter/widgets.dart';
import 'package:bloom_ui/bloom_ui.dart' as ui;
import 'package:go_router/go_router.dart';
import '../core/boot.dart';
import '../lifecycle/lifecycle.dart';
import '../router/router.dart';
import '../web/prerender_bridge.dart';

/// Root application widget for Bloom applications.
///
/// Wraps [ui.BloomApp.router], initializes the [BloomLifecycleManager],
/// attaches SSR/prerender signaling hooks, and wires GoRouter navigation.
///
/// Example:
/// ```dart
/// void main() => runApp(
///   BloomApp(
///     title: 'My App',
///     routes: [
///       BloomRouter.route(path: '/', builder: (context, match) => const HomeScreen()),
///     ],
///   ),
/// );
/// ```
class BloomApp extends StatefulWidget {
  /// Application title string displayed in task switchers and web document titles.
  final String? title;

  /// Custom [RouterConfig] instance. If omitted, constructed automatically from [routes].
  final RouterConfig<Object>? routerConfig;

  /// List of GoRouter route declarations used to build the default router.
  final List<RouteBase>? routes;

  /// Initial route location (defaults to `'/'`).
  final String initialLocation;

  /// Light theme definition.
  final ui.BloomTheme? theme;

  /// Dark theme definition.
  final ui.BloomTheme? darkTheme;

  /// Active theme mode (system, light, or dark).
  final ui.BloomThemeMode themeMode;

  /// Active application locale.
  final Locale? locale;

  /// Localization delegates for internationalization.
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  /// Supported locales list.
  final Iterable<Locale>? supportedLocales;

  /// Whether to show the debug banner in the top-right corner.
  final bool debugShowCheckedModeBanner;

  /// Fallback home widget when [routes] and [routerConfig] are not specified.
  final Widget? home;

  /// Creates a [BloomApp] root widget.
  const BloomApp({
    super.key,
    this.title,
    this.routerConfig,
    this.routes,
    this.initialLocation = '/',
    this.theme,
    this.darkTheme,
    this.themeMode = ui.BloomThemeMode.system,
    this.locale,
    this.localizationsDelegates,
    this.supportedLocales,
    this.debugShowCheckedModeBanner = false,
    this.home,
  });


  @override
  State<BloomApp> createState() => _BloomAppState();
}

class _BloomAppState extends State<BloomApp> {
  late final RouterConfig<Object> _resolvedRouter;

  @override
  void initState() {
    super.initState();
    BloomLifecycleManager.instance.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) => signalPrerenderReady());

    if (widget.routerConfig != null) {
      _resolvedRouter = widget.routerConfig!;
    } else if (widget.routes != null) {
      _resolvedRouter = BloomRouter.create(
        routes: widget.routes!,
        initialLocation: widget.initialLocation,
      );
    } else {
      // Default placeholder route if none provided
      _resolvedRouter = BloomRouter.create(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                widget.home ??
                ui.BloomScaffold(
                  header: SizedBox(
                    height: 56,
                    child: Container(
                      color: context.bloomColors.surface1,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text(widget.title ?? Bloom.config.name),
                        ],
                      ),
                    ),
                  ),
                  body: Center(
                    child: Text('Welcome to ${widget.title ?? Bloom.config.name}'),
                  ),
                ),
          ),
        ],
        initialLocation: widget.initialLocation,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ui.BloomApp.router(
      title: widget.title ?? Bloom.config.name,
      routerConfig: _resolvedRouter,
      theme: widget.theme ?? ui.BloomTheme.light,
      darkTheme: widget.darkTheme ?? ui.BloomTheme.dark,
      themeMode: widget.themeMode,
      locale: widget.locale,
      localizationsDelegates: widget.localizationsDelegates,
      supportedLocales: widget.supportedLocales ?? const [Locale('en', 'US')],
      debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
    );
  }
}
