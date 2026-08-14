# Bloom — Design System & Site Plan

Direction: keep the current aesthetic (glass panels, mesh gradients, petal motif) but tighten it into an actual **system** — tokens, a real icon library, a motion language, and a 3-landing architecture that shares one visual spine. Everything below is meant to be implementable in Astro + Preact islands.

---

## 1. Design Direction (one sentence each)

- **Voice**: technical-elegant, closer to Vercel/Linear than to a typical Flutter-community site. Confidence through restraint, not more gradients.
- **Motif**: the five-petal mark isn't decoration — it's the recurring visual anchor across all three landings (see §7).
- **Rule of thumb for "cleaner"**: every glass panel, blur, and gradient must justify itself against a flat alternative. If it's not carrying meaning (state, hierarchy, brand), cut it.

---

## 2. Tokenage (design tokens)

Formalize what's currently ad-hoc Tailwind config into a real token layer (`tokens.css` or a Style Dictionary source of truth → Tailwind theme extend).

### Color
```
--petal-pink:   #FF4B8B
--petal-orange: #FF884D
--petal-cyan:   #20C9B0
--petal-blue:   #3B82F6
--petal-purple: #8B5CF6

--surface-0 (page bg light/dark): #FAFAFA / #030509
--surface-1 (raised panel):       #FFFFFF / #0D1117
--surface-2 (glass):              rgba(255,255,255,.6) / rgba(13,17,23,.6)
--border-subtle:                  slate-200/50 / slate-800/50
--text-primary / secondary / tertiary  (3-step only — you currently drift between 4-5 grays, collapse it)
```
Each petal color needs a **semantic mapping**, not just a swatch — decide now, don't let it drift page to page:
- purple → primary action / framework (BUILD)
- blue → cloud / infra (SHIP)
- pink/orange/cyan → accent only, never primary CTA color

### Typography scale (modular, 1.25 ratio, base 16px)
```
--text-xs 12 / --text-sm 14 / --text-base 16 / --text-lg 18
--text-xl 20 / --text-2xl 25 / --text-3xl 31 / --text-4xl 39
--text-5xl 49 / --text-6xl 61 / --text-7xl 76 / --text-8xl 95
```
Two fonts stay (Plus Jakarta Sans / JetBrains Mono) — no third font. Mono is reserved for code, numbers, and the tagline strip only; don't let it leak into body copy.

### Spacing & radius
```
4px base spacing scale (4/8/12/16/24/32/48/64/96/128)
Radius: --r-sm 8px  --r-md 12px  --r-lg 16px  --r-xl 24px  --r-full 999px
```
Currently `currentRadius` in UI Studio defaults to 12 — make that the system default (`--r-md`) everywhere, not just in the demo widget.

### Elevation (shadow scale, replaces the 4 ad-hoc glass shadows)
```
--shadow-1: 0 1px 2px rgba(0,0,0,.04)
--shadow-2: 0 8px 32px rgba(31,38,135,.07)   // current "glass"
--shadow-3: 0 12px 40px -10px rgba(139,92,246,.15)  // hover glow
--shadow-4: 0 20px 60px -15px rgba(0,0,0,.25) // modal
```

### Motion tokens (see §4 for usage)
```
--ease-out: cubic-bezier(0.16, 1, 0.3, 1)
--ease-spring: cubic-bezier(0.175, 0.885, 0.32, 1.275)
--dur-instant: 120ms   (press states)
--dur-fast: 200ms      (hover, toggle)
--dur-base: 400ms      (panel transitions)
--dur-slow: 800ms      (reveals)
--dur-ambient: 6000-12000ms (float/breathe loops — leave as-is, already good)
```

### Z-index scale
```
--z-bg: -2   --z-grid: -1   --z-base: 0   --z-sticky: 50
--z-modal: 100   --z-toast: 110
```

---

## 3. Icon library

**Decision: adopt Lucide** (you already have it available in the React/Astro ecosystem, MIT-licensed, tree-shakeable, consistent 24px/2px-stroke grid). Drop any hand-drawn inline SVG icons except the petal mark and syntax-highlight-adjacent glyphs.

Rules:
- Stroke width fixed at `1.75` (Lucide default 2 reads slightly heavy against Plus Jakarta Sans's thinner weights)
- Two sizes only: `16px` (inline/badges) and `20px` (buttons/nav) — no ad-hoc `w-4 h-4` vs `w-5 h-5` scattered arbitrarily like in the current file
- Icons never carry brand color alone as their only affordance — pair with label or a colored container, for a11y and scan-ability
- The one exception to "use Lucide": the petal logomark and the 5 gradient petal-burst SVGs stay fully custom — that's your brand asset, not a generic icon

---

## 4. Animation system

Split into 4 tiers so you can reason about what's allowed where:

**Tier 1 — Micro-interactions** (buttons, cards, toggles)
- Hover: `translateY(-2px)` + shadow-3, `--dur-fast`, `--ease-out`
- Press: `scale(0.97)`, `--dur-instant`
- Focus-visible: 2px ring in petal-purple, no transition (instant, accessibility)

**Tier 2 — Scroll reveals** (section entrances)
- Currently missing entirely — right now everything is visible on load. Add `IntersectionObserver`-driven fade+8px-slide-up on section entry, staggered 60ms per child. Keep it subtle: opacity 0→1, translateY 12px→0, `--dur-slow`.
- This is the single highest-leverage addition for perceived polish — it's what makes a page feel "designed" vs "assembled."

**Tier 3 — Ambient/looping** (mesh float, petal breathe, marquee)
- Keep what exists, it's good. Just gate all of it behind:
```css
@media (prefers-reduced-motion: reduce) {
  .bg-mesh-animated, .petal-burst.active, .marquee, .animate-pulse-soft { animation: none; }
}
```

**Tier 4 — Narrative/state animations** (deploy terminal, phone simulator, radius/color live-preview)
- These are your strongest asset — they demonstrate the product instead of describing it. Extend the pattern rather than replacing it: every landing's hero demo should follow the same "press a button → watch real UI update" formula (see §7).

**Astro-specific addition**: use the [View Transitions API](https://docs.astro.build/en/guides/view-transitions/) (`<ClientRouter />`) for navigation between the 3 landings + hub. A shared-element transition on the petal logo (morphs position/scale between pages instead of hard-cutting) is the connective tissue that makes 4 separate pages feel like one product.

---

## 5. Visual enhancers

Keep, refine, and standardize into reusable primitives:

| Enhancer | Current state | Change |
|---|---|---|
| Mesh gradient bg | inline per-page | extract to `<AmbientMesh />` component, pass 3 hue anchors as props so each landing gets a themed variant (purple-dominant hub, blue-dominant Cloud page, etc.) |
| Glass panel | `.glass-panel` utility class | fine as-is, just consolidate the 4 near-duplicate glass/mouse-glow-card classes into one component with variants (`static` / `interactive`) |
| Grid overlay | fixed, always-on | fine, keep low-opacity, maybe fade it out below the fold via mask so it doesn't compete with content-heavy sections |
| Mouse-glow spotlight | cursor-tracked radial gradient on cards | good detail, extend to nav pills on hover for consistency |
| Grain/noise texture | **not present** | consider adding a very subtle (2-3% opacity) noise texture over the mesh gradients — flat gradients can look slightly "AI-generated cheap" at large sizes; grain is the classic fix, costs nothing perf-wise as a CSS `background-image: url(noise.svg)` |
| Gradient text sweep | present, used sparingly | good, don't add more of it — it's a "hero headline only" move |

---

## 6. Storytelling structure

Your tagline **BUILD • SHIP • BLOOM** is already a three-act narrative — right now it's used as a nav label, not a structure. Make it literal:

1. **BUILD** = the Dart/Flutter framework + DX (code editor, phone simulator) — currently your `#dx` section
2. **SHIP** = Cloud/OTA/deploy — currently your `#cloud-section`
3. **BLOOM** = the UI system coming together — currently your `#ui-studio`

Each act should escalate: BUILD shows you writing code, SHIP shows that code going live, BLOOM shows the polished result. Right now the section *order* on the single page is DX → Ecosystem → UI Studio → Cloud, which doesn't follow this arc. Reordering to **Build → Ship → Bloom** (matching the tagline literally) turns the scroll into a story instead of a feature list.

Add one connective narrative element: a **thin progress rail** on the left edge of the page (desktop only) that fills in petal-purple as the user scrolls through Build→Ship→Bloom, labeled with the three words. Cheap to build (scroll % → height), high narrative payoff.

---

## 7. Three landings connecting to one hub

### Architecture
```
bloom.dev/              → Hub (overview, teases all three, single strongest CTA)
bloom.dev/build         → Framework & DX deep-dive
bloom.dev/ship          → Cloud & deployment deep-dive
bloom.dev/bloom (or /ui)→ UI Studio & design system deep-dive
```

### What makes them feel like one product, not three microsites
1. **Shared shell**: identical header/footer/command-palette/theme-toggle components across all four routes (Astro layout component, not duplicated per-page).
2. **Shared token/motion system** from §2-4 — no page invents its own shadow or easing curve.
3. **Color-coded but not color-siloed**: each sub-landing gets a dominant accent (Build=purple, Ship=blue, Bloom=full petal gradient) applied to its `<AmbientMesh />` and primary buttons only — everything else (typography, spacing, glass panels) stays identical so it reads as "one system, three chapters," not three different brands.
4. **Cross-linking pattern**: each sub-landing's footer/final-CTA area previews the *next* chapter (Build page ends with "Now ship it →" linking to /ship, Ship ends with "See it in Bloom UI →"), literally walking the visitor through your tagline in page-to-page order. Hub page's three teaser cards double as this same entry point.
5. **The petal mark as connective thread**: on the hub, show all 5 petals closed/forming. On /build, /ship, /bloom, show the *specific* petal segment for that page's color highlighted/larger in the nav logo (subtle, not gimmicky) — reinforces "you're inside one part of a whole."
6. **View Transitions** (§4) morph the logo and header between routes so navigation doesn't hard-reload the shell.

### Per-landing content skeleton (keep identical structure across all 3 for predictability)
```
Hero (headline + one live interactive demo, same pattern as your phone simulator)
  ↓ scroll-reveal
Problem framing (2-3 sentences, what breaks without this)
  ↓
Deep interactive demo (your terminal / UI studio pattern — this is the "wow" section)
  ↓
Proof (metrics, logos, or a code diff showing before/after)
  ↓
Cross-link CTA to next chapter + secondary CTA to install/get-started
```

---

## 8. Reusable component/helper inventory

Build these once as Astro components (static) or Preact islands (interactive), used across all 4 pages:

**Static (Astro, zero JS)**
- `<Section>` — consistent vertical rhythm, scroll-reveal wrapper built in
- `<GlassPanel variant="static|interactive">`
- `<GradientText>` / `<SweepText>`
- `<AmbientMesh hue={...}>`
- `<PetalLogo highlight={...}>`
- `<Badge>`, `<MetricCard>` (static display variant)
- `<Footer>`, `<Navbar>`

**Interactive (Preact islands, `client:visible`)**
- `<PhoneSimulator>` — generalize your current `simulateSale()` widget so Ship/Bloom pages can reuse the phone frame with different demo content
- `<TerminalDeploy>` — generalize `triggerDeploy()`
- `<UIStudioPicker>` — color/radius live tokens demo
- `<CommandPalette>` — cmd+k, shared shell-wide
- `<ToastSystem>` — shared shell-wide
- `<ThemeToggle>` — shared shell-wide
- `<ScrollProgressRail>` — new, per §6

Centralizing these kills the current pattern of one 1200-line file with everything inlined, and means each new landing is mostly composition, not new code.

---

## 9. Accessibility & performance guardrails (bake in from day one)

- `prefers-reduced-motion` respected everywhere per §4
- Command palette: `role="dialog" aria-modal="true"`, focus trap, restore focus on close
- Theme toggle: `aria-pressed`, persist choice in `localStorage`
- Icon-only buttons: `aria-label` always
- Ship interactive islands with `client:visible`/`client:idle`, never `client:load`, so below-the-fold demos don't block first paint
- Target: hub page interactive-in-<2s on mid-tier mobile — the current all-JS single file is nowhere close to this

---

## 10. Rough sequencing

1. Extract tokens (§2) into a real theme file — this alone will surface every inconsistency in the current build
2. Swap in Lucide, retire ad-hoc inline icon SVGs
3. Build the shared shell (Navbar/Footer/CommandPalette/Toast/ThemeToggle) as components
4. Rebuild current single page as the **/build** landing using the new components + scroll-reveal system
5. Clone the pattern for **/ship** and **/bloom**
6. Build the **hub** last (it's mostly composition of teasers pulled from the three finished pages)
7. Add View Transitions + ScrollProgressRail as the final connective layer
