/// Internationalization (i18n) and localization (l10n) for Bloom full-stack applications.
///
/// Modeled on the `djangors-i18n` Rust crate's API design, `bloom_i18n` adopts standard
/// ICU MessageFormat syntax powered by `package:intl` and Dart/JSON maps. It provides
/// single-locale catalogs, multi-locale registries with fallback resolution, `Accept-Language`
/// HTTP middleware, and localized date/time formatters.
///
/// Example usage:
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
library;

export 'src/catalog.dart';
export 'src/locales.dart';
export 'src/locale_middleware.dart';
export 'src/date_format.dart';

