# Marketplace Flow Specification

The authoritative spec for the Bloom vs Next.js comparison. Both implementations
build **this** document, not their own interpretation of "a marketplace".

Scope: a multi-vendor marketplace — buyers, sellers, and operators. Every flow
below carries the best-practice constraint that makes it non-trivial, because
the constraint is what actually exercises a framework. "Create an order" is a
form POST; "create an order exactly once under a double-clicked submit button
and a retried payment webhook" is a framework test.

---

## 1. Identity and access

| # | Flow | The constraint that makes it hard |
|---|---|---|
| 1.1 | Buyer registration (email + password) | Password hashing with a memory-hard KDF; never reveal whether an email exists |
| 1.2 | Email verification | Single-use, expiring, signed token; unverified accounts limited not blocked |
| 1.3 | Social / OAuth login | Provider account linking to an existing email without takeover |
| 1.4 | Magic-link login | Single-use token, short TTL, invalidated on use |
| 1.5 | Session management | Rotating tokens, absolute + idle expiry, "sign out everywhere" |
| 1.6 | MFA (TOTP) enrolment + challenge | Recovery codes, single-use, rate-limited verification |
| 1.7 | Password reset | Token invalidation on use and on password change; session revocation |
| 1.8 | Seller onboarding + KYC | Multi-step resumable form, document upload, review queue, state machine |
| 1.9 | RBAC | buyer / seller / support / admin, with per-object authorization not just per-route |
| 1.10 | Account deletion + data export | GDPR: hard vs soft delete, order records legally retained |

**Cross-cutting:** every auth mutation is rate-limited per IP *and* per account;
CSRF protection on cookie-authenticated mutations; timing-safe comparisons.

## 2. Catalog

| # | Flow | Constraint |
|---|---|---|
| 2.1 | Product CRUD (seller) | Draft → review → published → archived state machine |
| 2.2 | Variants and SKUs | Option matrix (size × colour), per-variant price/stock/image |
| 2.3 | Category taxonomy | Nested tree, breadcrumb derivation, reparenting without orphaning |
| 2.4 | Attributes and facets | Typed attributes that become filterable facets |
| 2.5 | Media upload | Direct-to-storage upload, MIME sniffing (never trust extension), size caps, EXIF strip, responsive variants |
| 2.6 | Pricing | Base/sale price, currency, per-region tax class, price history |
| 2.7 | Inventory | Stock levels, **reservation during checkout**, oversell prevention under concurrency, backorder |
| 2.8 | Digital goods | Entitlement + expiring signed download URLs |
| 2.9 | Moderation queue | Operator approve/reject with reason, seller notification |
| 2.10 | SEO surface | Stable slugs, canonical URLs, Product/Offer JSON-LD, sitemap, OG images |

## 3. Discovery

| # | Flow | Constraint |
|---|---|---|
| 3.1 | Full-text search | Typo tolerance, synonyms, relevance ranking, per-locale analyzers |
| 3.2 | Faceted filtering | Facet counts that reflect the *current* filter set |
| 3.3 | Sorting | price/relevance/newest/rating, stable tie-breaking |
| 3.4 | Pagination | Cursor-based, stable under concurrent inserts (offset paging duplicates rows) |
| 3.5 | Recommendations | "Related", "recently viewed", cold-start behaviour |
| 3.6 | Merchandised collections | Operator-curated, scheduled publish |

## 4. Cart and checkout

| # | Flow | Constraint |
|---|---|---|
| 4.1 | Guest cart | Survives without an account; **merges** into the user cart on login without losing or duplicating lines |
| 4.2 | Cart mutation | Optimistic UI, server is authoritative on price and stock |
| 4.3 | Checkout revalidation | Price/stock/discount re-checked at submit; drift surfaced, never silently charged |
| 4.4 | Address entry | Validation/normalisation, saved addresses, per-country field shapes |
| 4.5 | Shipping rates | Zones, weight/dimensional rules, **per-vendor split shipments** |
| 4.6 | Tax calculation | VAT/GST/US sales tax, inclusive vs exclusive display, B2B reverse charge |
| 4.7 | Discounts | Coupons, automatic promotions, stacking and exclusivity rules, usage caps |
| 4.8 | Payment authorization | 3DS/SCA challenge, redirect return, wallet methods |
| 4.9 | Order placement | **Idempotent** under double submit and retry; single order per payment intent |
| 4.10 | Payment webhooks | Out-of-order and duplicate delivery, signature verification, replay window |
| 4.11 | Fraud/risk hold | Manual review state that blocks fulfilment but not order creation |

**The hard core of the whole spec:** 4.3, 4.7, 4.9 and 4.10 together. Stock
reservation, payment authorization and order creation must agree under
concurrency, partial failure and webhook retries.

## 5. Order lifecycle

| # | Flow | Constraint |
|---|---|---|
| 5.1 | Order state machine | pending → paid → fulfilled → delivered → completed, illegal transitions rejected |
| 5.2 | Split fulfilment | One buyer order, many vendor sub-orders, independent shipping |
| 5.3 | Tracking | Carrier updates ingested via webhook, buyer notification |
| 5.4 | Cancellation | Only in permitted states; stock restored; payment voided vs refunded |
| 5.5 | Returns / RMA | Request → approve → receive → refund, with per-line quantities |
| 5.6 | Refunds | Partial and full, idempotent, ledger-consistent |
| 5.7 | Disputes / chargebacks | Evidence submission, funds held |
| 5.8 | Invoices and receipts | Immutable, sequentially numbered, PDF, tax-compliant |

## 6. Multi-vendor operations

| # | Flow | Constraint |
|---|---|---|
| 6.1 | Vendor dashboard | Strictly scoped to own data — the classic IDOR surface |
| 6.2 | Commission model | Per-category or per-vendor rates, computed at order time and frozen |
| 6.3 | Ledger | Double-entry: order → commission → vendor balance; must always reconcile |
| 6.4 | Payouts | Scheduled batch, minimum threshold, failure and retry, statement |
| 6.5 | Split payments | Funds routed per vendor (Stripe Connect-style) |
| 6.6 | Vendor metrics | Fulfilment time, cancellation rate, rating; suspension thresholds |

## 7. Post-purchase and engagement

| # | Flow | Constraint |
|---|---|---|
| 7.1 | Reviews and ratings | Verified-purchase only, one per order line, moderation, aggregate recomputation |
| 7.2 | Product Q&A | Seller and community answers, moderation |
| 7.3 | Wishlist | Cross-device, price-drop notification |
| 7.4 | Notifications | Email + in-app + webhook, per-user preferences, unsubscribe, digesting |
| 7.5 | Abandoned cart | Scheduled job, suppression rules, one-click resume |

## 8. Operations and admin

| # | Flow | Constraint |
|---|---|---|
| 8.1 | Operator dashboard | Revenue/orders/GMV over time, cached and incrementally invalidated |
| 8.2 | Order/user/vendor administration | Search, filter, bulk action, safe destructive operations |
| 8.3 | Content moderation | Queue with SLA, reason codes |
| 8.4 | Audit log | Immutable who-did-what-when on every privileged mutation |
| 8.5 | Settings / feature flags | Runtime toggles without redeploy |
| 8.6 | Reporting export | Long-running CSV generation, delivered async |

## 9. Cross-cutting requirements

These apply to every flow above and are where frameworks genuinely differ.

- **Concurrency correctness** — optimistic locking or row-level guarantees on
  stock, balances and order state.
- **Idempotency** — client-supplied keys on every unsafe mutation; webhook
  handlers safe under duplicate delivery.
- **Caching and invalidation** — product/category pages cached; a price or stock
  change must invalidate *exactly* the affected pages. Tag-based invalidation.
- **Authorization** — enforced per object, at the data layer, not only in routes.
- **Rate limiting and bot defence** — on auth, search, checkout.
- **Observability** — structured logs, request tracing, error reporting.
- **i18n / l10n** — locale routing, translated catalogue, currency and date
  formatting, RTL.
- **Accessibility** — keyboard-operable checkout, form errors announced.
- **Security** — CSRF, XSS, SSRF on webhook/image URLs, upload sniffing, secrets
  handling, PCI scope minimisation.
- **Schema evolution** — migrations, zero-downtime deploys, backfills.
- **Testing** — unit, integration against a real database, end-to-end checkout.

---

## Benchmark tiers derived from this spec

1. **JSON API tier** — `/api/products` (paginated, filtered), `/api/orders`.
   Bloom server vs Fastify. No rendering; measures the HTTP/serialization path.
2. **SSR page tier** — product listing and product detail, uncached and cached.
   Bloom vs Next.js. This is where the headless-Chromium architecture is exposed.
3. **Mutation tier** — checkout submission under concurrency, measuring
   correctness (no oversell, no duplicate orders) as well as throughput.
4. **Cache invalidation tier** — price change → how much is invalidated and how
   fast the next request is served.

Production builds on both sides: `dart compile exe` / `next build && next start`
/ `NODE_ENV=production node server.js`. Fixed concurrency ladder, warmup
discarded, report p50/p95/p99 and RPS — never the mean.
