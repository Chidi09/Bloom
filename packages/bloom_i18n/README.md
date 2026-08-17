# bloom_i18n

Internationalization (i18n) and localization (l10n) for Bloom full-stack applications (both server-rendered strings, API routes, and client-side UI).

`bloom_i18n` is modeled on the `djangors-i18n` Rust crate's API design (catalogs, multi-locale fallback resolution, `Accept-Language` middleware layer, and localized date helpers). Rather than porting Mozilla's Fluent (FTL) parser—since pure-Dart Fluent implementations are immature—`bloom_i18n` adopts standard **ICU MessageFormat** syntax powered by Dart's real, standard `intl` package and plain Dart/JSON maps.

---

## Features

- **`BloomCatalog`**: Single-locale message store with ICU MessageFormat syntax (`{var}`, pluralization, select/gender cases).
- **`BloomLocales`**: Multi-locale registry with cascading fallback resolution (`requested locale` → `language subtag` → `default locale` → `default language subtag` → `messageId`).
- **`BloomLocaleMiddleware`**: Bloom HTTP middleware resolving `Accept-Language` header quality values (`q=`) or query overrides (`?locale=`), attaching `ResolvedLocale` to `BloomRequest`.
- **`localizedDate` / `localizedDateTime`**: Date and time formatting helpers powered by `package:intl`.

---

## Installation

Add `bloom_i18n` to your `pubspec.yaml`:

```yaml
dependencies:
  bloom_framework:
    path: ../bloom_framework
  bloom_i18n:
    path: ../bloom_i18n
  intl: ^0.19.0
```

---

## Usage Examples

### 1. Registering Two Locales with Plural & Interpolated Messages

```dart
import 'package:bloom_i18n/bloom_i18n.dart';

void main() {
  final locales = BloomLocales(defaultLocale: 'en-US');

  // Register English messages (interpolated argument + plural form)
  locales.addLocale('en-US', {
    'welcome_user': 'Welcome back, {username}!',
    'inbox_notifications': '{count, plural, =0 {No new notifications} =1 {1 new notification} other {# new notifications}}',
  });

  // Register Spanish messages
  locales.addLocale('es-ES', {
    'welcome_user': '¡Bienvenido de nuevo, {username}!',
    'inbox_notifications': '{count, plural, =0 {Sin notificaciones nuevas} =1 {1 nueva notificación} other {# nuevas notificaciones}}',
  });

  // --- English lookup ---
  print(locales.translate('en-US', 'welcome_user', args: {'username': 'Elena'}));
  // Output: "Welcome back, Elena!"

  print(locales.translate('en-US', 'inbox_notifications', args: {'count': 0}));
  // Output: "No new notifications"

  print(locales.translate('en-US', 'inbox_notifications', args: {'count': 1}));
  // Output: "1 new notification"

  print(locales.translate('en-US', 'inbox_notifications', args: {'count': 5}));
  // Output: "5 new notifications"

  // --- Spanish lookup ---
  print(locales.translate('es-ES', 'welcome_user', args: {'username': 'Carlos'}));
  // Output: "¡Bienvenido de nuevo, Carlos!"

  print(locales.translate('es-ES', 'inbox_notifications', args: {'count': 3}));
  // Output: "3 nuevas notificaciones"
}
```

---

### 2. Resolving Locale from `Accept-Language` via Middleware

```dart
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_i18n/bloom_i18n.dart';

void main() {
  final locales = BloomLocales(defaultLocale: 'en-US');
  locales.addLocale('en-US', {'greeting': 'Hello!'});
  locales.addLocale('fr-FR', {'greeting': 'Bonjour !'});
  locales.addLocale('es-ES', {'greeting': '¡Hola!'});

  final middleware = BloomLocaleMiddleware(
    defaultLocale: 'en-US',
    supportedLocales: ['en-US', 'fr-FR', 'es-ES'],
    locales: locales,
  );

  // Incoming HTTP request with weighted Accept-Language header:
  final request = BloomRequest(
    method: 'GET',
    uri: Uri.parse('https://example.com/api/greet'),
    headers: {
      'accept-language': 'fr-FR, fr;q=0.9, en;q=0.8, *;q=0.5',
    },
  );

  middleware.handle(request, () async {
    // Read the resolved locale tag attached to the request
    final resolvedLocale = request.locale; // "fr-FR"

    // Translate messages directly using the request extension
    final greeting = request.t('greeting'); // "Bonjour !"

    return BloomResponse.json({
      'locale': resolvedLocale,
      'message': greeting,
    });
  });
}
```

---

### 3. Formatting Dates for Multiple Locales

```dart
import 'package:bloom_i18n/bloom_i18n.dart';

void main() {
  final eventDate = DateTime(2026, 8, 17, 14, 30);

  // Format date for US English (M/d/y)
  final usDate = localizedDate(eventDate, 'en-US');
  print('US Date: $usDate'); // "8/17/2026"

  // Format date for French (d/M/y)
  final frDate = localizedDate(eventDate, 'fr-FR');
  print('FR Date: $frDate'); // "17/08/2026"

  // Format date and time for German
  final deDateTime = localizedDateTime(eventDate, 'de-DE');
  print('DE DateTime: $deDateTime'); // "17.8.2026 14:30:00"
}
```
