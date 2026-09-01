// lib/src/widgets/bloom_app.dart
import 'package:flutter/widgets.dart';

import '../theme/bloom_theme.dart';
import '../theme/bloom_theme_provider.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// Defines how the [BloomApp] selects between [BloomApp.theme] and [BloomApp.darkTheme].
enum BloomThemeMode {
  /// Use either the light or dark theme based on the host platform's brightness setting.
  system,

  /// Always use the light theme regardless of the platform setting.
  light,

  /// Always use the dark theme regardless of the platform setting.
  dark,
}

/// A Material-free modal route that page-transitions with a smooth fade and subtle slide.
///
/// Replaces Material's `MaterialPageRoute`.
///
/// ## Usage
/// ```dart
/// Navigator.of(context).push(
///   BloomPageRoute(
///     builder: (context) => const DetailScreen(),
///   ),
/// );
/// ```
class BloomPageRoute<T> extends PageRoute<T> {
  /// Builds the primary contents of the route.
  final WidgetBuilder builder;

  @override
  final bool maintainState;

  @override
  final bool fullscreenDialog;

  @override
  final Duration transitionDuration;

  /// Creates a [BloomPageRoute].
  BloomPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.transitionDuration = const Duration(milliseconds: 220),
  });

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

/// A basic structural page layout container replacing Material's `Scaffold`.
///
/// Provides a colored canvas, safe area padding, top [header], scrollable/expanded [body],
/// bottom [footer], and optional automatic bottom inset handling for software keyboards.
///
/// ## Usage
/// ```dart
/// BloomScaffold(
///   header: MyHeaderBar(),
///   body: Center(child: Text('Main Content')),
///   footer: MyFooterBar(),
/// );
/// ```
class BloomScaffold extends StatelessWidget {
  /// The primary content widget displayed in the scaffold body.
  final Widget body;

  /// An optional header widget pinned to the top of the safe area.
  final Widget? header;

  /// An optional footer widget pinned to the bottom of the safe area.
  final Widget? footer;

  /// Background color of the entire scaffold canvas. Defaults to [BloomColorScheme.surface0].
  final Color? backgroundColor;

  /// Whether the body should pad itself to avoid software keyboards. Defaults to `true`.
  final bool resizeToAvoidBottomInset;

  /// Creates a [BloomScaffold].
  const BloomScaffold({
    super.key,
    required this.body,
    this.header,
    this.footer,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = backgroundColor ?? context.bloomColors.surface0;
    final bottomInset = resizeToAvoidBottomInset
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        Expanded(child: body),
        if (footer != null) footer!,
      ],
    );

    if (bottomInset > 0) {
      content = Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: content,
      );
    }

    return ColoredBox(
      color: effectiveColor,
      child: SafeArea(
        child: content,
      ),
    );
  }
}

/// Root application widget that configures navigation, localization, typography,
/// and the active [BloomTheme] without any dependency on Material or Cupertino.
///
/// ## Usage
/// ```dart
/// import 'package:bloom_ui/bloom_ui.dart';
/// import 'package:flutter/widgets.dart';
///
/// void main() {
///   runApp(
///     const BloomApp(
///       theme: BloomTheme.novaLight,
///       home: BloomScaffold(
///         body: Center(
///           child: Text('Hello Bloom UI'),
///         ),
///       ),
///     ),
///   );
/// }
/// ```
///
/// ## Router Usage
/// ```dart
/// import 'package:bloom_ui/bloom_ui.dart';
/// import 'package:flutter/widgets.dart';
/// import 'package:go_router/go_router.dart';
///
/// void main() {
///   runApp(
///     BloomApp.router(
///       theme: BloomTheme.novaLight,
///       routerConfig: router,
///     ),
///   );
/// }
/// ```
class BloomApp extends StatelessWidget {
  /// The widget for the default route of the app (`/`).
  final Widget? home;

  /// The application's top-level routing table.
  final Map<String, WidgetBuilder> routes;

  /// The name of the first route to show.
  final String? initialRoute;

  /// The route generator callback used when the app is navigated to a named route.
  final RouteFactory? onGenerateRoute;

  /// Called when [onGenerateRoute] fails to resolve a route.
  final RouteFactory? onUnknownRoute;

  /// A key to use when accessing the [NavigatorState].
  final GlobalKey<NavigatorState>? navigatorKey;

  /// The list of observers for the [Navigator] created for this app.
  final List<NavigatorObserver> navigatorObservers;

  /// A delegate to parse the route information from the [routeInformationProvider].
  final RouteInformationParser<Object>? routeInformationParser;

  /// A delegate that configures a widget, typically a [Navigator], with parsed result from [routeInformationParser].
  final RouterDelegate<Object>? routerDelegate;

  /// A delegate that decides whether to handle the Android back button intent.
  final BackButtonDispatcher? backButtonDispatcher;

  /// An object that provides route information through the [RouteInformationProvider.value].
  final RouteInformationProvider? routeInformationProvider;

  /// An object to configure the underlying [Router].
  final RouterConfig<Object>? routerConfig;

  /// A one-line description used by the device to identify the app for the user.
  final String title;

  /// The [BloomTheme] to use when the app is rendered in light mode.
  final BloomTheme? theme;

  /// The [BloomTheme] to use when the app is rendered in dark mode.
  final BloomTheme? darkTheme;

  /// Controls which theme is used (light, dark, or system brightness). Defaults to [BloomThemeMode.system].
  final BloomThemeMode themeMode;

  /// The initial locale for this app's widgets.
  final Locale? locale;

  /// The delegates for this app's [Localizations] widget.
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  /// The list of locales that this app has been configured to accept.
  final Iterable<Locale> supportedLocales;

  /// A builder for wrapping the entire application widget subtree.
  final TransitionBuilder? builder;

  /// Turns on a little "DEBUG" banner in debug mode.
  final bool debugShowCheckedModeBanner;

  /// The primary color used by the operating system to represent the application.
  final Color? color;

  /// Creates a [BloomApp].
  const BloomApp({
    super.key,
    this.home,
    this.routes = const <String, WidgetBuilder>{},
    this.initialRoute,
    this.onGenerateRoute,
    this.onUnknownRoute,
    this.navigatorKey,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.title = '',
    this.theme,
    this.darkTheme,
    this.themeMode = BloomThemeMode.system,
    this.locale,
    this.localizationsDelegates,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.builder,
    this.debugShowCheckedModeBanner = true,
    this.color,
  }) : routeInformationProvider = null,
       routeInformationParser = null,
       routerDelegate = null,
       backButtonDispatcher = null,
       routerConfig = null;

  /// Creates a [BloomApp] that uses the [Router] instead of a [Navigator].
  ///
  /// If the [routerConfig] is provided, the other router related delegates,
  /// [routeInformationParser], [routeInformationProvider], [routerDelegate],
  /// and [backButtonDispatcher], must all be null.
  const BloomApp.router({
    super.key,
    this.routeInformationProvider,
    this.routeInformationParser,
    this.routerDelegate,
    this.routerConfig,
    this.backButtonDispatcher,
    this.title = '',
    this.theme,
    this.darkTheme,
    this.themeMode = BloomThemeMode.system,
    this.locale,
    this.localizationsDelegates,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.builder,
    this.debugShowCheckedModeBanner = true,
    this.color,
  }) : assert(
         routerDelegate != null || routerConfig != null,
         'Either one of routerDelegate or routerConfig must be provided',
       ),
       assert(
         routerConfig == null ||
             (routeInformationProvider == null &&
                 routeInformationParser == null &&
                 routerDelegate == null &&
                 backButtonDispatcher == null),
         'If the routerConfig is provided, all the other router delegates must not be provided',
       ),
       assert(
         routerConfig != null ||
             routeInformationProvider == null ||
             routeInformationParser != null,
         'If routeInformationProvider is provided, routeInformationParser must also be provided',
       ),
       home = null,
       routes = const <String, WidgetBuilder>{},
       initialRoute = null,
       onGenerateRoute = null,
       onUnknownRoute = null,
       navigatorKey = null,
       navigatorObservers = const <NavigatorObserver>[];

  bool get _usesRouter => routerDelegate != null || routerConfig != null;

  BloomTheme _resolveTheme(BuildContext context) {
    final brightness = MediaQuery.maybeOf(context)?.platformBrightness ?? Brightness.light;
    final bool isDark = switch (themeMode) {
      BloomThemeMode.system => brightness == Brightness.dark,
      BloomThemeMode.light => false,
      BloomThemeMode.dark => true,
    };
    if (isDark) {
      return darkTheme ?? BloomTheme.resolve(Brightness.dark);
    } else {
      return theme ?? BloomTheme.resolve(Brightness.light);
    }
  }

  Widget _buildWithTheme(BuildContext innerContext, Widget? child) {
    final resolvedTheme = _resolveTheme(innerContext);
    final effectiveTextStyle = TextStyle(
      fontFamily: resolvedTheme.typography.sans,
      fontSize: resolvedTheme.typography.base,
      color: resolvedTheme.colors.textPrimary,
    );

    Widget appChild = BloomThemeProvider(
      theme: resolvedTheme,
      child: DefaultTextStyle(
        style: effectiveTextStyle,
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (builder != null) {
      appChild = Builder(
        builder: (BuildContext contextBelowTheme) => builder!(contextBelowTheme, appChild),
      );
    }

    return appChild;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? theme?.colors.primary ?? BloomColors.petalPurple;

    if (_usesRouter) {
      return WidgetsApp.router(
        routeInformationProvider: routeInformationProvider,
        routeInformationParser: routeInformationParser,
        routerDelegate: routerDelegate,
        routerConfig: routerConfig,
        backButtonDispatcher: backButtonDispatcher,
        builder: _buildWithTheme,
        title: title,
        color: effectiveColor,
        locale: locale,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      );
    }

    return WidgetsApp(
      navigatorKey: navigatorKey,
      onGenerateRoute: onGenerateRoute,
      onUnknownRoute: onUnknownRoute,
      navigatorObservers: navigatorObservers,
      initialRoute: initialRoute,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return BloomPageRoute<T>(settings: settings, builder: builder);
      },
      home: home,
      routes: routes,
      builder: _buildWithTheme,
      title: title,
      color: effectiveColor,
      locale: locale,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }
}
