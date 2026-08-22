# bloom_ecommerce_server

The backend half of `bloom_js_ecommerce`: a small, real REST API for a basic
e-commerce catalog + cart + order flow, built directly on
`package:bloom_server/bloom_server.dart` — the Flutter-free HTTP core — plus
`bloom_db`, `bloom_validate`, `bloom_auth_server`, `bloom_errors`, `bloom_rest`,
`bloom_migrate`, and `bloom_security`. No Flutter dependency anywhere in this
package's resolved dependency graph.

## Running it

1. Install dependencies:

   ```bash
   dart pub get
   ```

2. Start a local Postgres instance and create a database (defaults to
   `bloom_ecommerce`, matching `.env.example`):

   ```bash
   createdb bloom_ecommerce
   ```

3. Copy the env file and adjust credentials if needed:

   ```bash
   cp .env.example .env
   ```

4. Run the server. It connects to Postgres, applies
   `migrations/ecommerce/0001_initial.sql` via `bloom_migrate`, then starts
   listening:

   ```bash
   dart run bin/server.dart
   ```

   You should see:

   ```
   Bloom E-Commerce Backend listening on port 8080
   Health Check: http://127.0.0.1:8080/api/health
   ```

## API walkthrough (curl)

```bash
# Health check
curl http://localhost:8080/api/health

# Sign up
curl -X POST http://localhost:8080/api/auth/signup \
  -H 'Content-Type: application/json' \
  -d '{"name": "Ada Lovelace", "email": "ada@example.com", "password": "correcthorse"}'
# => { "token": "...", "user": {...} }

# Log in
curl -X POST http://localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email": "ada@example.com", "password": "correcthorse"}'
# => { "token": "...", "user": {...} }

# Who am I (authenticated)
curl http://localhost:8080/api/auth/me \
  -H "Authorization: Bearer <token>"

# List products (public — no auth required)
curl http://localhost:8080/api/products

# Create a product (staff-only — the signup/login flow above issues a
# plain 'user' role; a 'staff' or 'admin' role must be granted out-of-band,
# e.g. directly in the database, for this example)
curl -X POST http://localhost:8080/api/products \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer <staff-token>" \
  -d '{"name": "Mechanical Keyboard", "description": "Hot-swappable, 75%", "priceCents": 12900, "imageUrl": "", "stockQuantity": 25}'

# Place an order (authenticated) — the server looks up each product's
# current price/stock and computes the total; it never trusts client-sent
# prices.
curl -X POST http://localhost:8080/api/orders \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer <token>" \
  -d '{"items": [{"productId": 1, "quantity": 2}]}'

# List my orders
curl http://localhost:8080/api/orders/mine \
  -H "Authorization: Bearer <token>"
```

## Routes

| Method | Path                 | Auth              | Description                          |
|--------|----------------------|-------------------|---------------------------------------|
| GET    | `/api/health`        | none              | Health check                          |
| POST   | `/api/auth/signup`   | none              | Create an account, returns a token    |
| POST   | `/api/auth/login`    | none              | Log in, returns a token               |
| GET    | `/api/auth/me`       | required          | Current authenticated user            |
| GET    | `/api/products`      | none              | List products                         |
| POST   | `/api/products`      | staff role        | Create a product                      |
| GET    | `/api/products/:pk`  | none              | Retrieve one product                  |
| PUT    | `/api/products/:pk`  | staff role        | Replace a product                     |
| PATCH  | `/api/products/:pk`  | staff role        | Partially update a product            |
| DELETE | `/api/products/:pk`  | staff role        | Delete a product                      |
| POST   | `/api/orders`        | required          | Place an order from cart line items   |
| GET    | `/api/orders/mine`   | required          | List the authenticated user's orders  |
