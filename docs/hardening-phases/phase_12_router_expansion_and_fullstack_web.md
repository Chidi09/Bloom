# Phase 12: Router Expansion, API Routes & Full-Stack Web (SSR/SSG)

> **Objective:** Expand Bloom Router beyond client-side navigation into a universal application platform supporting backend API routes (`/api/*`), Static Site Generation (SSG), Server-Side Rendering (SSR), route loaders/actions, sitemaps, and Progressive Web App (PWA) deployment.

---

## 🏗️ Universal Full-Stack Architecture

```text
                           lib/routes/
                                │
          ┌─────────────────────┴─────────────────────┐
          ▼                                           ▼
   Client Page Routes                          Backend API Routes
  (index.dart, [id].dart)                    (api/users.dart, api/auth.dart)
          │                                           │
  ┌───────┴───────┐                           ┌───────┴───────┐
  ▼               ▼                           ▼               ▼
Static HTML   Server Render             REST Handlers   Middleware
   (SSG)          (SSR)                 (GET/POST/DEL)  (Auth, CORS, Rate)
```

---

## 🌐 1. Backend API Routes (`lib/routes/api/`)

Create server-side HTTP endpoints simply by placing Dart files inside `lib/routes/api/`:

```dart
// lib/routes/api/users.dart
import 'package:bloom_framework/bloom_server.dart';

// GET /api/users
Future<BloomResponse> get(BloomRequest request) async {
  final users = await database.getAllUsers();
  return BloomResponse.json(users);
}

// POST /api/users
Future<BloomResponse> post(BloomRequest request) async {
  final body = await request.json();
  final newUser = await database.createUser(body);
  return BloomResponse.json(newUser, statusCode: 201);
}
```

### Dynamic Path Parameters
`lib/routes/api/users/[id].dart` automatically captures `:id`:
```dart
Future<BloomResponse> delete(BloomRequest request) async {
  final id = request.params['id'];
  await database.deleteUser(id);
  return BloomResponse.noContent();
}
```

---

## 🛡️ 2. API Route Middleware

Attach composable middleware for authentication, rate limiting, and CORS:

```dart
// lib/routes/api/admin/_middleware.dart
import 'package:bloom_framework/bloom_server.dart';

class AdminAuthMiddleware implements BloomMiddleware {
  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) async {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !isValidAdminToken(authHeader)) {
      return BloomResponse.forbidden('Admin authentication required.');
    }
    return await next();
  }
}
```

---

## ⏳ 3. Route Loaders & Actions (Data Fetching & Mutations)

Decouple data fetching from UI widget lifecycles:

```dart
// lib/routes/products/[id].dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

// Server-side / Build-time Data Loader
@BloomLoader()
Future<Product> loadProduct(BloomRouteContext context) async {
  final id = context.params['id']!;
  return await productService.getProductById(id);
}

// Form Action Handler
@BloomAction()
Future<ActionResult> updatePrice(BloomRouteContext context, Map<String, dynamic> form) async {
  final id = context.params['id']!;
  await productService.updatePrice(id, double.parse(form['price']));
  return ActionResult.success();
}
```

---

## ⚡ 4. Static Site Generation (`bloom build web --static`)

Compile your Bloom routes into fully rendered static HTML pages at build time:

```bash
bloom build web --static
```

### Generated Output (`build/web/`)
```text
build/web/
├── index.html                 # Prerendered HTML for '/'
├── about/index.html           # Prerendered HTML for '/about'
├── products/
│   ├── 1/index.html           # Prerendered HTML for '/products/1'
│   └── 2/index.html           # Prerendered HTML for '/products/2'
├── sitemap.xml                # Auto-generated XML Sitemap
├── robots.txt                 # Auto-generated Robots file
└── manifest.json              # Web PWA Manifest
```

---

## 🖥️ 5. Server-Side Rendering (`bloom build web --server`)

For dynamic, content-heavy applications requiring real-time HTML generation and dynamic OpenGraph social media cards:

```bash
bloom build web --server
```

Generates a high-performance Dart HTTP server (`server.dart`) that handles incoming HTTP requests, executes route loaders, renders HTML on the server, and hydrates the Flutter client application on the browser.

---

## 🔍 6. Declarative SEO & OpenGraph Metadata

Define search engine and social media metadata per route:

```dart
// lib/routes/blog/[slug].dart
class BlogPostRoute extends StatelessWidget {
  static BloomRouteMetadata metadata(BloomRouteContext context) => BloomRouteMetadata(
    title: 'How Bloom Revolutionizes Flutter',
    description: 'Learn how filesystem routing and Signals state elevate mobile development.',
    openGraph: OpenGraph(
      title: 'How Bloom Revolutionizes Flutter',
      image: 'https://bloom.dev/og/blog-post.png',
      type: 'article',
    ),
    canonical: 'https://bloom.dev/blog/${context.params['slug']}',
  );

  @override
  Widget build(BuildContext context) => ...;
}
```

---

## 📱 7. Progressive Web App (PWA) Support

`bloom.yaml` configures automated PWA asset generation:

```yaml
web:
  pwa:
    enabled: true
    name: "Bloom Storefront"
    short_name: "BloomShop"
    theme_color: "#10B981"
    background_color: "#FFFFFF"
    display: standalone
    service_worker:
      offline_cache: true
      strategy: cacheFirst
```

---

## 🧪 Verification & Acceptance Criteria

1. Files under `lib/routes/api/` compile to executable HTTP route handlers responding to GET, POST, PUT, and DELETE methods.
2. `bloom build web --static` generates pre-rendered HTML files for static and parameterized routes.
3. `bloom build web --server` starts an SSR Dart server that renders initial HTML and dynamic `<meta>` tags.
4. Sitemaps (`sitemap.xml`) and web manifests (`manifest.json`) are automatically generated and linked.
