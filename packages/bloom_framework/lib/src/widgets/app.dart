// lib/src/widgets/app.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/boot.dart';
import '../lifecycle/lifecycle.dart';
import '../router/router.dart';

/// Root application widget for Bloom applications.
/// Wraps [MaterialApp.router] and attaches the framework lifecycle system.
class BloomApp extends StatefulWidget {
  final String? title;
  final RouterConfig<Object>? routerConfig;
  final List<RouteBase>? routes;
  final String initialLocation;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode themeMode;
  final Locale? locale;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final Iterable<Locale>? supportedLocales;
  final bool debugShowCheckedModeBanner;
  final Widget? home;

  const BloomApp({
    super.key,
    this.title,
    this.routerConfig,
    this.routes,
    this.initialLocation = '/',
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
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
                Scaffold(
                  appBar: AppBar(title: Text(widget.title ?? Bloom.config.name)),
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
    return MaterialApp.router(
      title: widget.title ?? Bloom.config.name,
      routerConfig: _resolvedRouter,
      theme: widget.theme ?? ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      darkTheme: widget.darkTheme ??
          ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: Colors.deepPurple,
          ),
      themeMode: widget.themeMode,
      locale: widget.locale,
      localizationsDelegates: widget.localizationsDelegates,
      supportedLocales: widget.supportedLocales ?? const [Locale('en', 'US')],
      debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
    );
  }
}
