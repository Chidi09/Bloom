// Typed wrapper around `lucide` (installed via `bloom add npm:lucide` — see
// bloom.yaml / web/index.html). Loaded as an ES module through the import map
// in web/index.html; its bootstrap <script type="module"> assigns the full
// module namespace to `window.lucide` for this binding to find.
library;

import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('lucide')
extension type _LucideModule._(JSObject _) implements JSObject {
  external JSArray? get Github;
  external JSArray? get ExternalLink;
  external JSArray? get Mail;
  external JSArray? get Moon;
  external JSArray? get Sun;
  external JSArray? get Terminal;
  external JSArray? get Layers;
  external JSArray? get Cpu;
  external JSArray? get Code;
  external JSArray? get Sparkles;
  external JSArray? get Briefcase;
  external JSArray? get Send;
  external JSArray? get CheckCircle2;
  external JSArray? get AlertCircle;
  external JSArray? get MapPin;
  external JSArray? get Linkedin;
  external JSArray? get Twitter;
  external JSArray? get ArrowUpRight;
  external JSArray? get Check;
  external JSArray? get Copy;
  external JSArray? get Database;
  external JSArray? get Server;
  external JSArray? get Globe;
  external JSArray? get Activity;
  external JSArray? get User;
  external web.SVGElement createElement(JSArray iconNode);
}

@JS('lucide')
external _LucideModule? get _lucide;

enum LucideIconName {
  github,
  externalLink,
  mail,
  moon,
  sun,
  terminal,
  layers,
  cpu,
  code,
  sparkles,
  briefcase,
  send,
  checkCircle2,
  alertCircle,
  mapPin,
  linkedin,
  twitter,
  arrowUpRight,
  check,
  copy,
  database,
  server,
  globe,
  activity,
  user,
}

/// Renders Lucide icons as inline `<svg>` strings (via `lucide.createElement`
/// or fallback vector paths), suitable for Bloom's [Raw] node.
class LucideIcons {
  static final Map<String, String> _cache = {};

  /// Returns the SVG markup for the given icon.
  static String svg(LucideIconName name, {String className = 'w-4 h-4'}) {
    return _cache.putIfAbsent('${name.name}:$className', () {
      try {
        final lucide = _lucide;
        if (lucide != null) {
          final JSArray? iconNode = switch (name) {
            LucideIconName.github => lucide.Github,
            LucideIconName.externalLink => lucide.ExternalLink,
            LucideIconName.mail => lucide.Mail,
            LucideIconName.moon => lucide.Moon,
            LucideIconName.sun => lucide.Sun,
            LucideIconName.terminal => lucide.Terminal,
            LucideIconName.layers => lucide.Layers,
            LucideIconName.cpu => lucide.Cpu,
            LucideIconName.code => lucide.Code,
            LucideIconName.sparkles => lucide.Sparkles,
            LucideIconName.briefcase => lucide.Briefcase,
            LucideIconName.send => lucide.Send,
            LucideIconName.checkCircle2 => lucide.CheckCircle2,
            LucideIconName.alertCircle => lucide.AlertCircle,
            LucideIconName.mapPin => lucide.MapPin,
            LucideIconName.linkedin => lucide.Linkedin,
            LucideIconName.twitter => lucide.Twitter,
            LucideIconName.arrowUpRight => lucide.ArrowUpRight,
            LucideIconName.check => lucide.Check,
            LucideIconName.copy => lucide.Copy,
            LucideIconName.database => lucide.Database,
            LucideIconName.server => lucide.Server,
            LucideIconName.globe => lucide.Globe,
            LucideIconName.activity => lucide.Activity,
            LucideIconName.user => lucide.User,
          };

          if (iconNode != null) {
            final el = lucide.createElement(iconNode);
            el.setAttribute('class', className);
            return (el.outerHTML as JSString).toDart;
          }
        }
      } catch (_) {
        // Fall back to built-in pure SVG paths
      }
      return _fallbackSvg(name, className);
    });
  }

  /// Pure SVG vector fallback to ensure icons render even before JS bundles load
  /// or when offline/testing.
  static String _fallbackSvg(LucideIconName name, String className) {
    final inner = switch (name) {
      LucideIconName.github =>
        '<path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4"/><path d="M9 18c-4.51 2-5-2-7-2"/>',
      LucideIconName.externalLink =>
        '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>',
      LucideIconName.mail =>
        '<rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>',
      LucideIconName.moon =>
        '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
      LucideIconName.sun =>
        '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
      LucideIconName.terminal =>
        '<polyline points="4 17 10 11 4 5"/><line x1="12" x2="20" y1="19" y2="19"/>',
      LucideIconName.layers =>
        '<path d="m12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z"/><path d="m22 12.5-8.58 3.91a2 2 0 0 1-1.66 0L2 12.5"/><path d="m22 17.5-8.58 3.91a2 2 0 0 1-1.66 0L2 17.5"/>',
      LucideIconName.cpu =>
        '<rect width="16" height="16" x="4" y="4" rx="2"/><rect width="6" height="6" x="9" y="9" rx="1"/><path d="M15 2v2"/><path d="M15 20v2"/><path d="M2 15h2"/><path d="M2 9h2"/><path d="M20 15h2"/><path d="M20 9h2"/><path d="M9 2v2"/><path d="M9 20v2"/>',
      LucideIconName.code =>
        '<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>',
      LucideIconName.sparkles =>
        '<path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/>',
      LucideIconName.briefcase =>
        '<path d="M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/><rect width="20" height="14" x="2" y="6" rx="2"/>',
      LucideIconName.send =>
        '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
      LucideIconName.checkCircle2 =>
        '<path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z"/><path d="m9 12 2 2 4-4"/>',
      LucideIconName.alertCircle =>
        '<circle cx="12" cy="12" r="10"/><line x1="12" x2="12" y1="8" y2="12"/><line x1="12" x2="12.01" y1="16" y2="16"/>',
      LucideIconName.mapPin =>
        '<path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/>',
      LucideIconName.linkedin =>
        '<path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"/><rect width="4" height="12" x="2" y="9"/><circle cx="4" cy="4" r="2"/>',
      LucideIconName.twitter =>
        '<path d="M22 4s-.7 2.1-2 3.4c1.6 10-9.4 17.3-18 11.6 2.2.1 4.4-.6 6-2C3 15.5.5 9.6 3 5c2.2 2.6 5.6 4.1 9 4-.9-4.2 4-6.6 7-3.8 1.1 0 3-1.2 3-1.2z"/>',
      LucideIconName.arrowUpRight =>
        '<path d="M7 7h10v10"/><path d="M7 17 17 7"/>',
      LucideIconName.check =>
        '<polyline points="20 6 9 17 4 12"/>',
      LucideIconName.copy =>
        '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
      LucideIconName.database =>
        '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/><path d="M3 12c0 1.66 4 3 9 3s9-1.34 9-3"/>',
      LucideIconName.server =>
        '<rect width="20" height="8" x="2" y="2" rx="2" ry="2"/><rect width="20" height="8" x="2" y="14" rx="2" ry="2"/><line x1="6" x2="6.01" y1="6" y2="6"/><line x1="6" x2="6.01" y1="18" y2="18"/>',
      LucideIconName.globe =>
        '<circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/>',
      LucideIconName.activity =>
        '<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>',
      LucideIconName.user =>
        '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
    };

    return '<svg xmlns="http://www.w3.org/2000/svg" class="$className" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$inner</svg>';
  }
}
