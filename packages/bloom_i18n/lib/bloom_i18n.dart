/// Internationalization (i18n) and localization (l10n) for Bloom full-stack applications.
///
/// Modeled on the `djangors-i18n` Rust crate's API design, `bloom_i18n` adopts standard
/// ICU MessageFormat syntax powered by `package:intl` and Dart/JSON maps. It provides
/// single-locale catalogs, multi-locale registries with fallback resolution, `Accept-Language`
/// HTTP middleware, and localized date/time formatters.
///
/// ## Core Features
///
/// - **[BloomCatalog]**: A single-locale message catalog evaluating ICU MessageFormat
///   templates (variable interpolation, plurals, select/gender cases, numbers, and dates).
/// - **[BloomLocales]**: A multi-locale registry managing multiple catalogs with smart
///   fallback resolution (regional tag -> base language -> default locale -> message ID).
/// - **[BloomLocaleMiddleware]**: Server middleware for `bloom_server` resolving client
///   locales from query parameters (`?locale=`), `Accept-Language` headers (with quality
///   weighting), or server defaults, setting `Content-Language` headers on responses.
/// - **[BloomLocaleRequestExtension]**: Convenient `request.t('key')` and `request.locale`
///   accessors directly on incoming `BloomRequest` instances.
/// - **[localizedDate] / [localizedDateTime] & [BloomDateTimeI18n]**: Locale-aware date
///   and time formatting functions and extensions on [DateTime].
///
/// ## Example: Translation & Pluralization
///
/// ```dart
/// import 'package:bloom_i18n/bloom_i18n.dart';
///
/// void main() {
///   final locales = BloomLocales(defaultLocale: 'en-US');
///
///   // Register English messages (interpolated argument + plural form)
///   locales.addLocale('en-US', {
///     'welcome_user': 'Welcome back, {username}!',
///     'inbox_notifications': '{count, plural, =0 {No new notifications} =1 {1 new notification} other {# new notifications}}',
///   });
///
///   // Register Spanish messages
///   locales.addLocale('es-ES', {
///     'welcome_user': '¡Bienvenido de nuevo, {username}!',
///     'inbox_notifications': '{count, plural, =0 {Sin notificaciones nuevas} =1 {1 nueva notificación} other {# nuevas notificaciones}}',
///   });
///
///   // Lookup with arguments and plurals
///   print(locales.translate('en-US', 'welcome_user', args: {'username': 'Elena'}));
///   // Output: "Welcome back, Elena!"
///
///   print(locales.translate('es-ES', 'inbox_notifications', args: {'count': 3}));
///   // Output: "3 nuevas notificaciones"
/// }
/// ```
///
/// ## Example: Server Middleware
///
/// ```dart
/// import 'package:bloom_server/bloom_server.dart';
/// import 'package:bloom_i18n/bloom_i18n.dart';
///
/// void main() {
///   final locales = BloomLocales(defaultLocale: 'en-US');
///   locales.addLocale('en-US', {'greeting': 'Hello, {name}!'});
///   locales.addLocale('fr-FR', {'greeting': 'Bonjour, {name}!'});
///
///   final app = BloomServer();
///   app.use(BloomLocaleMiddleware(
///     defaultLocale: 'en-US',
///     supportedLocales: ['en-US', 'fr-FR'],
///     locales: locales,
///   ));
///
///   app.get('/greet', (req) {
///     final message = req.t('greeting', args: {'name': 'Amélie'});
///     return BloomResponse.ok(message);
///   });
/// }
/// ```
///
/// ## Example: Date & Time Formatting
///
/// ```dart
/// import 'package:bloom_i18n/bloom_i18n.dart';
///
/// final now = DateTime(2026, 8, 24, 14, 30);
///
/// // Using top-level functions
/// print(localizedDate(now, 'en-US')); // "8/24/2026"
/// print(localizedDate(now, 'en-GB')); // "24/08/2026"
///
/// // Using DateTime extension methods
/// print(now.toLocalizedDate('fr-FR')); // "24/08/2026"
/// print(now.toLocalizedDateTime('en-US')); // "8/24/2026 2:30:00 PM"
/// ```
library;

export 'src/catalog.dart';
export 'src/locales.dart';
export 'src/locale_middleware.dart';
export 'src/date_format.dart';

