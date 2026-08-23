# Bloom Portfolio Showcase

A single-page developer portfolio landing application built with **Bloom JS Native**, demonstrating high-performance pure-Dart web development with compiled DOM descriptors, fine-grained `signals` reactivity, type-safe JS interop, responsive images, accessible forms, and server/client SEO.

---

## Features & Highlights

- ⚡ **Pure Dart Web Development**: Declarative UI built with `BloomNode` AST descriptors (`Div`, `Section`, `H1`-`H3`, `Button`, `Form`, `Input`, `Textarea`), compiled to native browser DOM nodes.
- 🎨 **Engineering Aesthetics**: Dark carbon visual design inspired by Linear and Vercel with crisp borders, subtle glows, and seamless light/dark mode switching.
- 🖼️ **Responsive Image Optimization**: Project covers and bio portraits use Bloom's `bloomImage` API with explicit layout stability (CLS prevention), asynchronous decoding, and responsive width descriptors.
- 📝 **Type-Safe Reactive Forms**: Interactive contact form powered by `BloomForm` and `BloomFormField` with inline error validation, dirty/touched tracking, and asynchronous submission.
- 📜 **Type-Safe JS Interop Bindings**: Typed Dart wrappers under `lib/plugins/` interfacing with modern npm modules via browser ESM import maps:
  - **GSAP (`gsap`)**: Reveal and stagger animations on scroll.
  - **Lucide (`lucide`)**: Crisp vector icons rendered seamlessly.
  - **Typed.js (`typed.js`)**: Dynamic role typing effect in the hero.
  - **Lenis (`lenis`)**: Smooth momentum scrolling.
  - **GitHub Calendar (`github-calendar`)**: Real open-source commit activity graph.
  - **EmailJS (`@emailjs/browser`)**: Client-side contact form dispatch.
  - **Canvas Confetti (`canvas-confetti`)**: Celebration flourish on message sent.
- 🔍 **SEO & Metadata**: Complete head metadata, Open Graph cards, and Twitter summary tags driven by `package:bloom_seo`.
- ♿ **WAI-ARIA & Accessibility**: Semantic HTML landmarks, ARIA labels, live regions, keyboard navigation, and `prefers-reduced-motion` compliance.

---

## Getting Started

### 1. Prerequisites

Ensure you have the Dart SDK installed (version `>=3.5.0 <4.0.0`).

### 2. Running Locally

From within this directory (`examples/bloom_portfolio`):

```bash
# Start the Bloom JS development server
bloom js dev
```

Or run directly using the Bloom CLI tool:

```bash
dart run bloom_cli js dev
```

Open `http://localhost:8080` in your browser.

---

## Configuring EmailJS

The contact form is configured to send messages directly from the browser using [EmailJS](https://www.emailjs.com/).

By default, the application runs in **demo mode** with placeholder credentials. In demo mode, submitting the form simulates a successful transmission, fires the confetti burst, and displays a friendly configuration notice.

To connect your real EmailJS account:

1. Sign up for a free account at [emailjs.com](https://www.emailjs.com/).
2. Create an **Email Service** (e.g., Gmail, Outlook, or SMTP) and copy the **Service ID**.
3. Create an **Email Template** with fields `{{name}}`, `{{email}}`, and `{{message}}`, and copy the **Template ID**.
4. Go to **Account > API Keys** and copy your **Public Key**.
5. Open [`lib/config.dart`](lib/config.dart) and update the constants:

```dart
class EmailJsConfig {
  static const String serviceId = 'service_xxxxxxx';
  static const String templateId = 'template_xxxxxxx';
  static const String publicKey = 'pub_xxxxxxx';
}
```

---

## Asset & Resource Attribution

- **Images**: High-resolution imagery from [Unsplash](https://unsplash.com/) with explicit dimension query parameters.
- **Hero Video**: Decorative looping visual from [GIPHY](https://giphy.com/) (muted, playsinline, with poster image fallback).
- **Typography**: Google Fonts ([Inter](https://fonts.google.com/specimen/Inter) and [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono)).
- **Icons**: [Lucide Icons](https://lucide.dev/).
- **Activity Data**: Illustrative sample open-source commit history fetched dynamically via `github-calendar`.
