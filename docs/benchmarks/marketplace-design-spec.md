# Marketplace Design Specification

The visual contract for both implementations. Companion to
`marketplace-flow-spec.md`, which defines *what* the app does; this defines
*how it looks*.

**Both sides must render the same design.** Otherwise the comparison measures
two designers rather than two frameworks. The design is therefore specified as
tokens first. The Next.js side realises those tokens through shadcn/ui; the
Bloom side realises the identical tokens through its own components, because
shadcn is React and has no Dart equivalent. Same tokens, same spacing, same
type scale, same iconography — different means.

---

## 1. Brand palette

Teal-forward. Deliberately not purple and not dark blue. Teal reads as
commerce-credible and modern, and — the practical reason — it leaves red,
amber and green entirely free for status semantics, so brand colour and
"this order failed" can never be confused.

```
Brand
  --brand-50   #F0FDFA
  --brand-100  #CCFBF1
  --brand-200  #99F6E4
  --brand-500  #14B8A6
  --brand-600  #0D9488   <- primary. Buttons, active nav, links, focus ring
  --brand-700  #0F766E   <- hover / pressed
  --brand-900  #134E4A   <- headings on light, brand surfaces on dark

Accent (sparingly: promotions, "new", featured merchandising)
  --accent-500 #F59E0B
  --accent-600 #D97706

Semantic (never reuse brand for these)
  --success    #16A34A     order paid, in stock, payout sent
  --warning    #D97706     low stock, review pending, action needed
  --danger     #DC2626     failed payment, out of stock, destructive action
  --info       #0EA5E9     neutral informational notices

Neutrals — stone, i.e. a warm-biased grey. A pure grey reads as unconsidered;
the warm bias keeps large table surfaces from looking clinical.
  --n-0   #FFFFFF
  --n-50  #FAFAF9
  --n-100 #F5F5F4
  --n-200 #E7E5E4   <- borders, dividers
  --n-400 #A8A29E   <- placeholder, disabled
  --n-500 #78716C   <- secondary text
  --n-700 #44403C
  --n-900 #1C1917   <- primary text
  --n-950 #0C0A09   <- dark-mode ground
```

Usage discipline: one brand colour carries the page. If the accent starts
competing with the primary, the accent is wrong, not the primary.

**Dark mode is required** on the dashboard. Define the full light palette on
`:root`, redefine only tokens under `@media (prefers-color-scheme: dark)` and
under an explicit `[data-theme="dark"]`, and never give a colour its only
definition inside a theme block.

## 2. Typography

Pairing, both from Google Fonts:

- **Plus Jakarta Sans** — headings, page titles, section headers, metric
  numbers on the dashboard. Weights 500/600/700.
- **Inter** — body copy, form labels, table cells, everything dense. Weights
  400/500/600.

```
--font-display: 'Plus Jakarta Sans', system-ui, sans-serif;
--font-body:    'Inter', system-ui, sans-serif;
```

Scale (rem, 16px base):

```
display  2.25 / 1.15  600  Plus Jakarta   page hero, empty states
h1       1.875/ 1.2   600  Plus Jakarta
h2       1.5  / 1.25  600  Plus Jakarta
h3       1.25 / 1.3   600  Plus Jakarta
body     1.0  / 1.55  400  Inter
small    0.875/ 1.5   400  Inter          table cells, helper text
label    0.8125/1.4   500  Inter          form labels, uppercase eyebrows (+0.04em)
```

**Money and quantities must use `font-variant-numeric: tabular-nums`.** Prices
in a column that do not align are the single most obvious tell of an unpolished
commerce UI. Body copy caps at ~68 characters.

## 3. Iconography

**HugeIcons**, stroke style, 1.5px stroke, 20px default in UI and 16px inside
dense tables. One icon family throughout — no emoji as UI icons, and no mixing
in a second icon set for "the one that was missing".

Icons are never the only signal for state: a status pill is icon **and** text
and colour, so it survives colour-blindness and greyscale printing.

## 4. Layout

```
--radius-sm  6px    inputs, badges
--radius-md  10px   buttons, cards
--radius-lg  14px   modals, panels
--space      4px base scale: 4 8 12 16 24 32 48 64
--shadow-sm  0 1px 2px rgb(28 25 23 / .06)
--shadow-md  0 4px 12px rgb(28 25 23 / .08)
```

Use flex/grid with `gap` for sibling spacing, never per-element margins.
Wide content — order tables, line items — scrolls inside its own
`overflow-x: auto` container; the page body never scrolls sideways.

**Storefront:** max content width 1280px, generous whitespace, product imagery
leads. Product grid 2 columns on mobile, 3 on tablet, 4 on desktop.

**Dashboard:** persistent left sidebar (240px, collapsible to 64px icon rail),
sticky top bar with search and account, content area max 1440px. Density is a
feature here — operators scan hundreds of rows.

## 5. Component contract

Next.js uses shadcn/ui for these. Bloom builds equivalents against the same
tokens. Both must produce the same visual result.

| Component | Requirements |
|---|---|
| Button | primary / secondary / ghost / destructive; loading state that keeps its width; disabled is not just faded, it is non-focusable-looking |
| Input, Select, Textarea | Label always present (never placeholder-as-label); error text below, `aria-describedby`-linked; invalid state on the field, not only the message |
| Table | Sticky header, zebra-free (borders only), sortable column affordance, row-hover, empty state, skeleton loading |
| Card | Used for dashboard metrics and product tiles; no accent rail down the side |
| Badge / status pill | Semantic colour + icon + text; one per order state |
| Modal / Sheet | Focus trapped, ESC closes, restores focus to trigger |
| Toast | Announces via `aria-live`; success and error visually distinct |
| Pagination | Cursor-based controls; disabled ends, never a dead-end |
| Form | Errors summarised at top on submit *and* inline; first invalid field focused |

Every interactive element has a visible focus ring: `2px --brand-600` with a
2px offset. Respect `prefers-reduced-motion` — transitions drop to none.

## 6. Anti-patterns

Do not produce these; they are the generic-AI-design signature:

- Purple, indigo, or dark-navy primaries (also explicitly ruled out by the brief)
- Purple→blue gradient heroes
- Emoji as section markers or status icons
- Everything centred; `rounded-lg` on absolutely everything
- Accent bars down the left edge of cards
- Cream `#F4F1EA` + terracotta + serif display
- Numbered `01 / 02 / 03` markers on content that is not a sequence
- Placeholder text standing in for labels
- Fake data that looks fake: use realistic product names, prices and dates

## 7. Accessibility floor

Non-negotiable, and part of the flow spec's cross-cutting requirements:

- Contrast ≥ 4.5:1 for body text, ≥ 3:1 for large text and UI boundaries.
  `--brand-600` on white passes; `--brand-500` on white does **not** for body
  text — use it for fills, not for text.
- Full keyboard operability through the entire checkout.
- Form errors announced to assistive technology, not merely coloured red.
- Every image has meaningful `alt`; decorative images have empty `alt`.
- Respects `prefers-reduced-motion` and `prefers-color-scheme`.
