# bloom_server

> **Bloom Server is the Flutter-free Dart backend for full-stack web applications: HTTP APIs, SSR, SSG/ISR delivery, routing, middleware, and dependency injection.** Pair it with `bloom_js_native` for browser-to-server Dart without a JavaScript application layer.

This package is the Flutter-free extraction of what used to be reachable only via `package:bloom_framework/bloom_server.dart`, so packages that only need server/HTTP primitives never need the Flutter SDK.

Provides `BloomApiRouter` (routing, middleware, SSR via `bloom_js_native`), `BloomRequest`/`BloomResponse`, `BloomEnvironmentSchema`/env config, and a DI `Container`/`Scope` — all on pure `dart:io` with no Flutter SDK required.

## Features

- `BloomApiRouter` — high-performance HTTP router with `get`/`post`/`put`/`delete`/`patch`/`all` registration, path-parameter matching (`/api/tasks/:id`), wildcard captures, global and per-route middleware pipelines, specificity-based route sorting, request-body size guards, and graceful shutdown via `close()`. Includes `ssr()` for server-rendering a `BloomNode` tree from `bloom_js_native` to HTML, `serve()`/`listen()` to bind a real `dart:io` `HttpServer`, and `enableOpenApi()`/`toOpenApiSpec()` for OpenAPI 3.1 generation with Scalar / Swagger UI.
- `BloomRequest` / `BloomResponse` — typed, testable HTTP abstractions decoupled from `dart:io` (constructible directly in unit tests). `BloomResponse` helpers: `json`, `html`, `text`, `noContent`, `redirect`, `unauthorized`, `forbidden`, `notFound`, `payloadTooLarge`, `error`.
- `BloomMiddleware` — composable middleware interface (`handle` / `BloomNextFunction`) plus `FunctionalBloomMiddleware` and built-in `BloomCorsMiddleware`.
- `BloomEnvironmentSchema` / `BloomEnv` — strictly-typed, validated env-var schema (`requireString`, `optionalInt`, `requireBool`, `requireUri`, etc.) backed by a runtime map that also ingests `.env` files and `--dart-define` values.
- `BloomContainer` / `BloomTestScope` — lightweight DI container with transient/singleton/value bindings, hierarchical parent lookup, test overrides (`BloomTestOverride`), and an isolated `BloomTestScope` that activates a child container for the duration of a test.

## Usage

```dart
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';

void main() async {
  final router = BloomApiRouter();

  // JSON API route.
  router.get('/api/hello', (req) async {
    return BloomResponse.json({'message': 'Hello, Bloom!'});
  });

  // SSR route — renders a BloomNode tree to HTML in <1ms.
  router.ssr(
    '/',
    (req) => Div(
      className: 'min-h-screen bg-black text-white p-8',
      children: [
        H1(className: 'text-4xl font-extrabold', text: 'Bloom Edge SSR'),
        P(className: 'text-zinc-400 mt-2', text: 'Rendered instantly on the server.'),
      ],
    ),
    head: (req) => HeadManager(
      initialTitle: 'Bloom — Fast SSR & Edge Delivery',
      meta: {
        'description': 'Pure Dart server-side rendered landing page.',
        'og:title': 'Bloom Web Platform',
        'twitter:card': 'summary_large_image',
      },
    ),
  );

  await router.serve(port: 8080);
}
```

## Part of Bloom Server

`bloom_server` is the foundation of **Bloom Server**, the backend stack for the Bloom framework. Scaffold a full project with `bloom server create <name>` (from `bloom_cli`), or see `examples/bloom_fullstack_todo` in the [Bloom monorepo](https://github.com/bloom-framework/bloom) for a reference project wiring every Bloom Server package together against real PostgreSQL.

## License

MIT
