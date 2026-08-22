# bloom_ecommerce_web

The frontend half of `bloom_js_ecommerce`: a pure-Dart (no Flutter) storefront
built with `bloom_js_native` — fine-grained signals, `BloomQuery`/`BloomMutation`
for data fetching and caching, and client-side routing via `BloomRouterController`.

It talks to `bloom_ecommerce_server` (see `../server/README.md`) over a real
REST API at `http://localhost:8080/api`.

## Running it

Make sure `bloom_ecommerce_server` is running first (see `../server/README.md`)
— this app expects it on `localhost:8080`.

Using this repo's Bloom CLI dev server (recommended — live reload + automatic
compilation), from this directory:

```bash
dart pub get
bloom js dev --port 3000
```

Then open `http://localhost:3000`. (Port 3000 is used here since the backend
already occupies 8080.)

Alternatively, compile a static bundle and serve `web/` with any static file
server:

```bash
dart pub get
dart compile js lib/main.dart -o web/main.js
# then serve the web/ directory, e.g.:
dart pub global run dhttpd --path web --port 3000
```

## Pages

- `/` — product grid, fetched via `BloomQuery` and cached client-side.
- `/cart` — cart contents, quantity controls, running total, and checkout
  (posts to `/api/orders` via `BloomMutation`).
- `/login` — combined login/signup form; stores the returned session token
  in-memory (bloom_js_native currently has no browser `localStorage` helper,
  so the token does not persist across a page reload).
