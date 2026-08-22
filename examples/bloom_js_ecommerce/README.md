# bloom_js_ecommerce

A basic e-commerce example proving that **bloom_js_native** (the pure-Dart,
Flutter-free frontend) and **Bloom Server** (the new Flutter-free backend
package, `bloom_server`) work together as a genuine fullstack pair — a real
REST API, a real Postgres-backed backend, and a real browser client talking
to it over HTTP. This is a flagship reference example, not a toy.

## What's different from `bloom_fullstack_todo`

`bloom_fullstack_todo` exercises all 15 Bloom Server packages (mail, jobs,
storage, realtime, cache, i18n, admin, ...) and imports the backend through
the older `package:bloom_framework/bloom_server.dart` path, which pulls in
Flutter transitively.

`bloom_js_ecommerce/server` is intentionally leaner: it imports
`package:bloom_server/bloom_server.dart` **directly**, and depends only on
`bloom_server`, `bloom_db`, `bloom_validate`, `bloom_auth_server`,
`bloom_errors`, `bloom_rest`, `bloom_migrate`, and `bloom_security`. There is
no Flutter dependency anywhere in this backend's resolved dependency graph —
which is the whole point of this example existing: it proves `bloom_server`
is a legitimate, self-sufficient backend on its own.

## Structure

- [`server/`](server/README.md) — the REST API backend: products, auth
  (signup/login/me), and an order-placement flow that computes totals
  server-side from live product prices (never trusts client-submitted
  prices). See `server/README.md` for setup and a curl walkthrough.
- [`web/`](web/README.md) — the storefront frontend: a product grid, cart,
  and login/signup UI built with `bloom_js_native`'s HTML builders, signals,
  `BloomQuery`/`BloomMutation`, and client-side routing. See `web/README.md`
  for how to run it.

## Quick start

```bash
# Terminal 1 — backend
cd server
dart pub get
cp .env.example .env
createdb bloom_ecommerce
dart run bin/server.dart

# Terminal 2 — frontend
cd web
dart pub get
bloom js dev --port 3000
```

Then open `http://localhost:3000`.
