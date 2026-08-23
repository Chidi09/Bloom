// tool/generate_reference.dart
//
// Emits `reference/llms-full.txt`: a single flat, machine-readable digest of the
// entire bloom_js_native public API, assembled directly from the source so that
// it cannot drift from what the package actually exports.
//
// Why this exists
// ---------------
// bloom_js_native is a new framework. There is no Stack Overflow answer, no blog
// post, and no prior art for any of it. The only ground truth is this repository.
// A developer -- or a coding model asked to build something with Bloom -- has no
// way to discover the API except by reading 22k lines of source. This file is the
// substitute: every public symbol, its real signature, and its documentation, in
// one file small enough to paste into a context window.
//
// The cardinal rule for anything downstream of this file: if a symbol does not
// appear here, it does not exist. That is what makes the digest useful as an
// anti-fabrication grounding document.
//
// Usage:
//   dart run tool/generate_reference.dart
//
// This reads only `lib/`, writes only `reference/llms-full.txt`, and takes no
// arguments. Re-run it whenever the public API changes.

import 'dart:io';

/// A single documented declaration recovered from a source file.
class Decl {
  Decl({
    required this.kind,
    required this.name,
    required this.signature,
    required this.doc,
    required this.members,
  });

  /// `class`, `mixin`, `enum`, `typedef`, `function`, `getter`, `constant`, ...
  final String kind;

  /// The bare identifier, used for sorting and the symbol index.
  final String name;

  /// The declaration line as written, minus any trailing `{`.
  final String signature;

  /// Doc comment lines with the leading `/// ` stripped.
  final List<String> doc;

  /// Public members, for container declarations.
  final List<Decl> members;
}

/// Declaration keywords that introduce a type rather than a callable.
const _typeKeywords = <String>[
  'abstract base class',
  'abstract final class',
  'abstract interface class',
  'abstract class',
  'sealed class',
  'base mixin class',
  'base class',
  'final class',
  'interface class',
  'mixin class',
  'extension type',
  'class',
  'mixin',
  'enum',
  'extension',
  'typedef',
];

bool _isPrivate(String name) => name.startsWith('_');

final _ident = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

/// Index of the `(` that opens the parameter list.
///
/// This is the LAST top-level `(`, not the first. A return type may itself
/// contain a parameter list -- `String? Function(String) required([...])` -- and
/// taking the first would read `Function` as the declared name. Anything nested
/// inside the real parameter list is at depth > 0 and cannot be mistaken for it.
int _paramParen(String s) {
  var angle = 0, paren = 0, best = -1;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '<') angle++;
    if (c == '>') angle--;
    if (c == '(') {
      if (paren == 0 && angle <= 0) best = i;
      paren++;
    }
    if (c == ')') paren--;
  }
  return best;
}

/// Truncates at the first top-level `=`, so that an initialiser cannot be
/// mistaken for a declaration: in `BloomContainer _active = BloomContainer()`
/// the trailing `()` would otherwise be read as a parameter list and report the
/// name as `BloomContainer`.
String _beforeAssignment(String s) {
  var angle = 0, paren = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '<') angle++;
    if (c == '>') angle--;
    if (c == '(') paren++;
    if (c == ')') paren--;
    if (c == '=' && paren == 0 && angle <= 0) {
      // `==` is a comparison, never a declaration boundary. `=>` IS one: an
      // arrow body such as `StyleNode f() => StyleNode(css)` contains a call
      // whose parentheses would otherwise be read as f's parameter list.
      if (i + 1 < s.length && s[i + 1] == '=') continue;
      return s.substring(0, i);
    }
  }
  return s;
}

/// Pulls the identifier out of a declaration line.
///
/// This has to cope with generic return types: in `BloomQuery<T> query<T>(...)`
/// a naive "first identifier before the first angle bracket" reads the RETURN
/// type and reports the function as `BloomQuery`, silently duplicating the class
/// of the same name. The name is always the identifier that immediately precedes
/// the parameter list, or -- for a type -- the one right after the keyword.
String _nameOf(String line) {
  var s = line.trim();

  for (final kw in _typeKeywords) {
    if (s.startsWith('$kw ')) {
      var rest = s.substring(kw.length + 1).trim();
      final cut = rest.indexOf(RegExp(r'[<({=\s]'));
      if (cut > 0) rest = rest.substring(0, cut);
      return _ident.hasMatch(rest) ? rest : '';
    }
  }

  // An initialiser can contain anything, including a constructor call that looks
  // like a parameter list, so discard it before any structural analysis.
  s = _beforeAssignment(s);

  // Getter: `Foo get bar`.
  final getter = RegExp(r'\bget\s+([A-Za-z_$][A-Za-z0-9_$]*)').firstMatch(s);
  if (getter != null && _paramParen(s) < 0) return getter.group(1)!;

  // Callable: take the identifier immediately before the parameter list. Strip
  // generic argument lists rather than truncating at the first `<`, which would
  // reduce `Future<bool> loadLocale(...)` to its return type.
  final p = _paramParen(s);
  if (p > 0) {
    var head = s.substring(0, p);
    var prev = '';
    while (prev != head) {
      prev = head;
      head = head.replaceAll(RegExp(r'<[^<>]*>'), ' ');
    }
    final parts =
        head.trim().split(RegExp(r'[\s.]+')).where((x) => x.isNotEmpty).toList();
    if (parts.isNotEmpty && _ident.hasMatch(parts.last)) return parts.last;
    return '';
  }

  // Field or constant: last identifier on the line.
  var head = s;
  var prev = '';
  while (prev != head) {
    prev = head;
    head = head.replaceAll(RegExp(r'<[^<>]*>'), ' ');
  }
  final parts =
      head.trim().split(RegExp(r'[\s.]+')).where((x) => x.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final last = parts.last;
  return _ident.hasMatch(last) ? last : '';
}

String _kindOf(String line) {
  final s = line.trim();
  for (final kw in _typeKeywords) {
    if (s.startsWith('$kw ')) return kw;
  }
  if (RegExp(r'\bget\s+\w+').hasMatch(s) && !s.contains('(')) return 'getter';
  if (s.startsWith('const ') || s.startsWith('final ')) return 'constant';
  return 'function';
}

/// True for a line that begins a public declaration at the given indent depth.
bool _isDeclStart(String raw, {required bool topLevel}) {
  final line = raw.trimLeft();
  final indent = raw.length - line.length;
  if (topLevel && indent != 0) return false;
  if (!topLevel && (indent == 0 || indent > 2)) return false;
  if (line.isEmpty) return false;
  if (line.startsWith('//') || line.startsWith('@')) return false;
  if (line.startsWith('import ') || line.startsWith('export ')) return false;
  if (line.startsWith('library') || line.startsWith('part ')) return false;
  if (line.startsWith('}') || line.startsWith(')')) return false;
  // A member line must look like a declaration, not a statement.
  if (!topLevel && !RegExp(r'^[A-Za-z_@<]').hasMatch(line)) return false;
  return true;
}

/// Collapses a declaration that spans several lines into one signature string.
String _joinSignature(List<String> lines, int start) {
  final buf = StringBuffer();
  var depth = 0;
  for (var i = start; i < lines.length && i < start + 40; i++) {
    final l = lines[i].trim();
    buf.write(buf.isEmpty ? l : ' $l');
    for (final c in l.split('')) {
      if (c == '(' || c == '<' || c == '[') depth++;
      if (c == ')' || c == '>' || c == ']') depth--;
    }
    if (l.endsWith('{') || l.endsWith(';') || l.endsWith('=>')) {
      if (depth <= 0) break;
    }
  }
  var s = buf.toString();
  final brace = s.indexOf(' {');
  if (brace > 0) s = s.substring(0, brace);
  if (s.endsWith('{')) s = s.substring(0, s.length - 1).trimRight();
  if (s.endsWith(';')) s = s.substring(0, s.length - 1);
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<Decl> _parse(String source, {required bool topLevel, int? fromLine, int? toLine}) {
  final lines = source.split('\n');
  final out = <Decl>[];
  final lo = fromLine ?? 0;
  final hi = toLine ?? lines.length;

  var doc = <String>[];
  for (var i = lo; i < hi; i++) {
    final raw = lines[i];
    final t = raw.trim();

    if (t.startsWith('///')) {
      // Strip exactly one space after the slashes, never more: doc comments
      // carry fenced ```dart examples whose relative indentation is meaningful,
      // and trimming it left would flatten every example into one column.
      var body = t.substring(3);
      if (body.startsWith(' ')) body = body.substring(1);
      doc.add(body);
      continue;
    }
    if (t.startsWith('@') || t.isEmpty || t.startsWith('//')) {
      if (t.isEmpty) doc = <String>[];
      continue;
    }

    if (_isDeclStart(raw, topLevel: topLevel)) {
      final sig = _joinSignature(lines, i);
      final name = _nameOf(sig);
      if (name.isEmpty || _isPrivate(name)) {
        doc = <String>[];
        continue;
      }
      final kind = _kindOf(sig);
      final members = <Decl>[];

      // For a container, recurse over its body to collect public members.
      if (_typeKeywords.contains(kind) && kind != 'typedef' && raw.contains('{')) {
        var depth = 0;
        var end = i;
        for (var j = i; j < lines.length; j++) {
          for (final c in lines[j].split('')) {
            if (c == '{') depth++;
            if (c == '}') depth--;
          }
          if (depth == 0 && j > i) {
            end = j;
            break;
          }
        }
        members.addAll(_parse(source, topLevel: false, fromLine: i + 1, toLine: end));
      }

      out.add(Decl(kind: kind, name: name, signature: sig, doc: doc, members: members));
      doc = <String>[];
    } else {
      doc = <String>[];
    }
  }
  return out;
}

void main() {
  final libDir = Directory('lib/src');
  if (!libDir.existsSync()) {
    stderr.writeln('Run this from the bloom_js_native package root.');
    exitCode = 1;
    return;
  }

  // Which barrel exports which file decides whether a symbol is usable on the
  // server, in the browser, or both -- the single most common thing a reader
  // gets wrong, so it is recorded per file.
  final core = File('lib/bloom_js_native.dart').readAsStringSync();
  final browser = File('lib/browser.dart').readAsStringSync();
  String barrelFor(String base) {
    final inCore = core.contains("src/$base");
    final inBrowser = browser.contains("src/$base");
    if (inCore && inBrowser) return 'both';
    if (inBrowser) return 'browser-only (package:bloom_js_native/browser.dart)';
    if (inCore) return 'core (package:bloom_js_native/bloom_js_native.dart)';
    return 'not exported';
  }

  final files = libDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final buf = StringBuffer();
  final index = <String, String>{};

  buf.writeln('# bloom_js_native - complete public API reference');
  buf.writeln();
  buf.writeln('Generated by tool/generate_reference.dart. Do not edit by hand.');
  buf.writeln();
  buf.writeln('This is the COMPLETE public surface of the package. If a symbol is');
  buf.writeln('not listed here, it does not exist -- do not guess at APIs, and do');
  buf.writeln('not invent parameters, constructors, or fields.');
  buf.writeln();
  buf.writeln('Two entry points:');
  buf.writeln('  import \'package:bloom_js_native/bloom_js_native.dart\';  // core, SSR-safe');
  buf.writeln('  import \'package:bloom_js_native/browser.dart\';          // browser/DOM only');
  buf.writeln();
  buf.writeln('Anything marked "browser-only" touches package:web and must never be');
  buf.writeln('imported from server-side rendering code.');
  buf.writeln();
  buf.writeln('=' * 78);
  buf.writeln();

  // signals.dart is a pure `export 'package:signals/signals.dart'`, so it has no
  // declarations of its own to parse -- yet it supplies signal/computed/effect,
  // the most-used symbols in the framework. Without this block the digest would
  // claim they do not exist, which is the one thing it must never do.
  buf.writeln('## signals.dart (re-exported from package:signals)');
  buf.writeln('Availability: ${barrelFor('signals.dart')}');
  buf.writeln();
  buf.writeln('These come from `package:signals` and are re-exported so that Bloom');
  buf.writeln('code needs no direct dependency on it. Full semantics are documented');
  buf.writeln('by that package; the Bloom-relevant contract is:');
  buf.writeln();
  // Names are stated explicitly rather than derived: `_nameOf` locates a name by
  // the parameter list that follows it, and a signature like
  // `void Function() effect(...)` contains an earlier `()` belonging to the
  // return type, which would make it read the wrong token.
  for (final e in const [
    ['signal', 'Signal<T> signal<T>(T value)', 'Mutable reactive state container. Read `.value` to subscribe, assign `.value` to notify.'],
    ['computed', 'ReadonlySignal<T> computed<T>(T Function() fn)', 'Derived state; re-evaluates when any signal read inside `fn` changes.'],
    ['effect', 'void Function() effect(void Function() fn)', 'Runs `fn`, re-running it whenever a signal it read changes. Returns a dispose function -- CALL IT to avoid leaks.'],
    ['batch', 'T batch<T>(T Function() fn)', 'Coalesces multiple signal writes into a single notification pass.'],
    ['untracked', 'T untracked<T>(T Function() fn)', 'Reads signals without subscribing the enclosing effect/computed.'],
    ['Signal', 'class Signal<T> extends ReadonlySignal<T>', 'Writable signal. Because it extends ReadonlySignal, a base class may declare ReadonlySignal and a leaf narrow it to Signal.'],
    ['ReadonlySignal', 'class ReadonlySignal<T>', 'Read-only view of reactive state.'],
  ]) {
    buf.writeln('### ${e[0]}  [re-export]');
    buf.writeln('```dart');
    buf.writeln(e[1]);
    buf.writeln('```');
    buf.writeln(e[2]);
    buf.writeln();
    index[e[0]] = 'signals.dart (re-export)';
  }
  buf.writeln('-' * 78);
  buf.writeln();

  var total = 0;
  for (final f in files) {
    final base = f.path.split('/').last;
    final decls = _parse(f.readAsStringSync(), topLevel: true);
    if (decls.isEmpty) continue;

    buf.writeln('## $base');
    buf.writeln('Availability: ${barrelFor(base)}');
    buf.writeln();

    for (final d in decls) {
      total++;
      index[d.name] = base;
      buf.writeln('### ${d.name}  [${d.kind}]');
      buf.writeln('```dart');
      buf.writeln(d.signature);
      buf.writeln('```');
      if (d.doc.isNotEmpty) {
        for (final line in d.doc) {
          buf.writeln(line.isEmpty ? '' : line);
        }
      }
      if (d.members.isNotEmpty) {
        buf.writeln();
        buf.writeln('Members:');
        for (final m in d.members) {
          final summary = m.doc.isEmpty
              ? ''
              : '  -- ${m.doc.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')}';
          buf.writeln('  - `${m.signature}`$summary');
        }
      }
      buf.writeln();
    }
    buf.writeln('-' * 78);
    buf.writeln();
  }

  final sortedIndex = index.keys.toList()..sort();
  buf.writeln('## Symbol index');
  buf.writeln();
  for (final k in sortedIndex) {
    buf.writeln('  $k -> ${index[k]}');
  }

  Directory('reference').createSync(recursive: true);
  File('reference/llms-full.txt').writeAsStringSync(buf.toString());

  // The full digest is ~450 KB, which is too large to paste wholesale into a
  // context window. `llms.txt` is the same surface reduced to one line per
  // symbol -- enough to know what exists and what it is called, after which the
  // full file can be consulted for the specific entries that matter.
  final compact = StringBuffer();
  compact.writeln('# bloom_js_native - public API index (compact)');
  compact.writeln();
  compact.writeln('One line per public symbol. For full docs and examples see');
  compact.writeln('reference/llms-full.txt. If a symbol is not listed here, it');
  compact.writeln('does not exist.');
  compact.writeln();
  for (final f in files) {
    final base = f.path.split('/').last;
    final decls = _parse(f.readAsStringSync(), topLevel: true);
    if (decls.isEmpty) continue;
    compact.writeln('## $base  [${barrelFor(base)}]');
    for (final d in decls) {
      final summary =
          d.doc.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      compact.writeln('  ${d.signature}');
      if (summary.isNotEmpty) compact.writeln('      $summary');
    }
    compact.writeln();
  }
  File('reference/llms.txt').writeAsStringSync(compact.toString());

  stdout.writeln('Wrote reference/llms-full.txt');
  stdout.writeln('Wrote reference/llms.txt');
  stdout.writeln('  files:   ${files.length}');
  stdout.writeln('  symbols: $total');
}
