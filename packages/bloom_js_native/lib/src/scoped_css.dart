// lib/src/scoped_css.dart
//
// Pure-Dart Scoped CSS & CSS Modules module for Bloom JS Native.
// Safe for both SSR (VM) and browser DOM mounting with identical deterministic output.

import 'framework.dart';

/// Computes a deterministic 32-bit FNV-1a hash over [input].
///
/// Operates strictly within 32-bit unsigned integer arithmetic using bitwise operations
/// and additions to guarantee identical hash outputs across both the Dart VM (SSR, tests)
/// and Web compilers (dart2js, dart2wasm, DDC).
///
/// ```dart
/// final hash = fnv1a32('.card { color: red; }');
/// print(hash.toRadixString(16));
/// ```
int fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    hash ^= (code & 0xFF);
    // 32-bit multiplication by FNV prime 16777619 (0x01000193) via bitwise shifts:
    // 16777619 = 1 + (1<<1) + (1<<4) + (1<<7) + (1<<8) + (1<<24)
    hash = (hash +
            (hash << 1) +
            (hash << 4) +
            (hash << 7) +
            (hash << 8) +
            (hash << 24)) &
        0xFFFFFFFF;
    final high = code >> 8;
    if (high != 0) {
      hash ^= (high & 0xFF);
      hash = (hash +
              (hash << 1) +
              (hash << 4) +
              (hash << 7) +
              (hash << 8) +
              (hash << 24)) &
          0xFFFFFFFF;
    }
  }
  return hash & 0xFFFFFFFF;
}

/// A scoped CSS stylesheet bundle providing deterministic class name isolation.
///
/// Generated via [scopedCss] or [ScopedCss.compile]. Re-writes author CSS selectors
/// so that all local class selectors are suffixed with a unique, deterministic hash
/// derived from the stylesheet content and optional component [name].
///
/// ### Determinism across SSR and Browser
/// The scoping transformation is a pure function over strings without any DOM or
/// browser dependencies. The exact same [ScopedCss] instance or identical input string
/// produces bit-for-bit identical class names and CSS output on both the server
/// (SSR via `renderToHtml`) and the client (browser DOM via `mount`).
///
/// ### Selector Scoping Rules
/// - **Class Selectors**: All local class selectors (`.title`, `.btn-primary`) are scoped.
/// - **Escape Hatch (`:global`)**: Class names wrapped in `:global(...)` (e.g. `:global(.dark) .card`
///   or `.btn:global(.active)`) are preserved verbatim without scoping.
/// - **Preserved Selectors**: Element selectors (`div`, `p`), ID selectors (`#header`), `:root`,
///   and universal selectors (`*`) are left untouched.
/// - **At-Rules**: Nested rules inside `@media`, `@supports`, `@container`, and `@layer` blocks
///   are scoped recursively. Keyframe selectors (`from`, `to`, `0%`, `100%`) inside `@keyframes`
///   blocks are preserved verbatim.
///
/// ```dart
/// final styles = scopedCss('''
///   .card {
///     padding: 16px;
///     background: #14141a;
///     border: 1px solid #27272a;
///   }
///   .card:hover {
///     border-color: #6366f1;
///   }
///   :global(.theme-dark) .card {
///     background: #09090b;
///   }
/// ''', name: 'card');
///
/// BloomNode cardWidget(String titleText) => Div(
///   className: styles['card'],
///   children: [
///     styles.node,
///     H1(className: styles['title'], text: titleText),
///   ],
/// );
/// ```
class ScopedCss {
  /// The raw, un-scoped CSS source provided by the author.
  final String rawCss;

  /// The transformed CSS stylesheet with all local class selectors scoped.
  final String css;

  /// The deterministic 7-character hex hash derived from the CSS content and [name].
  final String hash;

  /// The optional human-readable component name prefix (e.g. `'card'`, `'button'`).
  final String? name;

  /// Lookup map from author class names (e.g. `'title'`) to generated scoped class names
  /// (e.g. `'card_title__a1b2c3d'`).
  final Map<String, String> classes;

  /// The [StyleNode] descriptor containing the transformed [css], ready to drop into
  /// a [BloomNode] tree.
  final StyleNode node;

  /// Alias for [node] for convenient stylesheet embedding.
  StyleNode get style => node;

  /// Creates a [ScopedCss] instance by compiling [rawCss] with an optional component [name].
  factory ScopedCss(String rawCss, {String? name}) = ScopedCss.compile;

  /// Compiles [rawCss] into a scoped stylesheet with class name mappings.
  factory ScopedCss.compile(String rawCss, {String? name}) {
    final seed = name != null && name.isNotEmpty ? '$name:$rawCss' : rawCss;
    final hashInt = fnv1a32(seed);
    final hashStr = hashInt.toRadixString(16).padLeft(8, '0').substring(0, 7);

    final scoper = _CssScoper(rawCss, hashStr, name);
    final transformedCss = scoper.process();
    final immutableClasses = Map<String, String>.unmodifiable(scoper.classes);

    return ScopedCss._(
      rawCss: rawCss,
      css: transformedCss,
      hash: hashStr,
      name: name,
      classes: immutableClasses,
      node: StyleNode(transformedCss),
    );
  }

  const ScopedCss._({
    required this.rawCss,
    required this.css,
    required this.hash,
    required this.name,
    required this.classes,
    required this.node,
  });

  /// Looks up the generated scoped class name for author [className].
  ///
  /// Returns the scoped class name if found in the stylesheet (e.g. `'button_title__a1b2c3d'`).
  /// If [className] was not present in the scoped stylesheet, returns [className] unchanged
  /// so that global utility classes or dynamic class names pass through safely.
  ///
  /// ```dart
  /// final cls = styles['card'];
  /// ```
  String operator [](String className) => classes[className] ?? className;

  /// Functional lookup shorthand — equivalent to `this[className]`.
  ///
  /// ```dart
  /// final cls = styles('card');
  /// ```
  String call(String className) => classes[className] ?? className;

  /// Looks up the generated scoped class name for author [className].
  ///
  /// Returns the scoped class name if defined, or [className] if not found.
  String get(String className) => classes[className] ?? className;

  /// Composes a class list resolving author class names to their scoped equivalents.
  ///
  /// Evaluates each part in [parts]:
  /// - `null` and `false` values are ignored.
  /// - String tokens present in [classes] are replaced with their scoped class name.
  /// - Unmatched string tokens (e.g. utility classes like `'p-4'`, `'flex'`) are preserved as-is.
  /// - Joins all resolved tokens with single spaces, identical to [cx].
  ///
  /// ```dart
  /// final isActive = true;
  /// final className = styles.cx([
  ///   'card',
  ///   isActive && 'active',
  ///   'p-4 flex',
  /// ]);
  /// // => 'card_card__a1b2c3d card_active__a1b2c3d p-4 flex'
  /// ```
  String cx(List<Object?> parts) {
    final out = StringBuffer();
    for (final part in parts) {
      if (part == null || part == false) continue;
      final s = part.toString().trim();
      if (s.isEmpty) continue;

      final tokens = s.split(RegExp(r'\s+'));
      for (final token in tokens) {
        if (token.isEmpty) continue;
        final resolved = classes[token] ?? token;
        if (out.isNotEmpty) out.write(' ');
        out.write(resolved);
      }
    }
    return out.toString();
  }
}

/// Creates a new [ScopedCss] module from [css] with an optional component [name].
///
/// Deterministically parses and rewrites all local class selectors in [css] to isolate
/// them under a short content-derived hash.
///
/// ```dart
/// final buttonStyles = scopedCss('''
///   .btn {
///     padding: 8px 16px;
///     border-radius: 6px;
///     background: #6366f1;
///     color: #ffffff;
///   }
///   .btn:hover {
///     background: #4f46e5;
///   }
///   .btn.disabled {
///     opacity: 0.5;
///     pointer-events: none;
///   }
/// ''', name: 'btn');
///
/// BloomNode submitButton(bool isDisabled) => Button(
///   className: buttonStyles.cx(['btn', isDisabled && 'disabled']),
///   children: [
///     buttonStyles.node,
///     const Text('Submit'),
///   ],
/// );
/// ```
ScopedCss scopedCss(String css, {String? name}) =>
    ScopedCss.compile(css, name: name);

// ─── Scoper Implementation ───────────────────────────────────────────────────

bool _isWhitespace(int code) =>
    code == 32 || code == 9 || code == 10 || code == 13 || code == 12;

bool _isIdentStart(int code) =>
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122) ||
    code == 95 /* _ */ ||
    code == 45 /* - */ ||
    code >= 160;

bool _isIdentChar(int code) =>
    _isIdentStart(code) || (code >= 48 && code <= 57);

class _CssScoper {
  final String css;
  final String hash;
  final String? name;
  final Map<String, String> classes = {};

  _CssScoper(this.css, this.hash, this.name);

  String process() => _parseStylesheet(css);

  String _getScopedClassName(String className) {
    if (classes.containsKey(className)) {
      return classes[className]!;
    }
    final scoped = name != null && name!.isNotEmpty
        ? '${name}_${className}__$hash'
        : '${className}__$hash';
    classes[className] = scoped;
    return scoped;
  }

  String _parseStylesheet(String input) {
    final out = StringBuffer();
    var i = 0;
    final len = input.length;

    while (i < len) {
      if (_isWhitespace(input.codeUnitAt(i))) {
        out.write(input[i]);
        i++;
        continue;
      }

      // Comments /* ... */
      if (i + 1 < len && input[i] == '/' && input[i + 1] == '*') {
        final end = input.indexOf('*/', i + 2);
        if (end == -1) {
          out.write(input.substring(i));
          break;
        } else {
          out.write(input.substring(i, end + 2));
          i = end + 2;
          continue;
        }
      }

      // At-rules
      if (input[i] == '@') {
        final atRuleEnd = _parseAtRule(input, i, out);
        i = atRuleEnd;
        continue;
      }

      // Regular Style Rules
      final selectorStart = i;
      final braceIndex = _findNextRuleOpenBrace(input, i);
      if (braceIndex == -1) {
        out.write(input.substring(i));
        break;
      }

      final rawSelector = input.substring(selectorStart, braceIndex);
      final rewrittenSelector = _rewriteSelectorList(rawSelector);
      out.write(rewrittenSelector);

      final blockEnd = _findMatchingClosingBrace(input, braceIndex);
      if (blockEnd == -1) {
        out.write(input.substring(braceIndex));
        break;
      } else {
        out.write(input.substring(braceIndex, blockEnd + 1));
        i = blockEnd + 1;
      }
    }

    return out.toString();
  }

  int _parseAtRule(String input, int start, StringBuffer out) {
    final len = input.length;
    var nameEnd = start + 1;
    while (nameEnd < len && _isIdentChar(input.codeUnitAt(nameEnd))) {
      nameEnd++;
    }
    final keyword = input.substring(start, nameEnd).toLowerCase();

    var nextSemicolon = -1;
    var nextBrace = -1;
    var j = nameEnd;
    var inString = 0;
    var inComment = false;
    var parenDepth = 0;

    while (j < len) {
      final c = input.codeUnitAt(j);
      if (inComment) {
        if (j + 1 < len && input[j] == '*' && input[j + 1] == '/') {
          inComment = false;
          j += 2;
          continue;
        }
        j++;
        continue;
      }
      if (j + 1 < len && input[j] == '/' && input[j + 1] == '*') {
        inComment = true;
        j += 2;
        continue;
      }
      if (inString != 0) {
        if (c == 92 && j + 1 < len) {
          j += 2;
          continue;
        }
        if (c == inString) inString = 0;
        j++;
        continue;
      }
      if (c == 34 || c == 39) {
        inString = c;
        j++;
        continue;
      }
      if (c == 40) {
        parenDepth++;
        j++;
        continue;
      }
      if (c == 41) {
        if (parenDepth > 0) parenDepth--;
        j++;
        continue;
      }
      if (parenDepth == 0) {
        if (c == 59 /* ; */) {
          nextSemicolon = j;
          break;
        }
        if (c == 123 /* { */) {
          nextBrace = j;
          break;
        }
      }
      j++;
    }

    if (nextSemicolon != -1 && (nextBrace == -1 || nextSemicolon < nextBrace)) {
      out.write(input.substring(start, nextSemicolon + 1));
      return nextSemicolon + 1;
    }

    if (nextBrace == -1) {
      out.write(input.substring(start));
      return len;
    }

    final atRuleHeader = input.substring(start, nextBrace);
    final blockEnd = _findMatchingClosingBrace(input, nextBrace);
    if (blockEnd == -1) {
      out.write(input.substring(start));
      return len;
    }

    final blockContent = input.substring(nextBrace + 1, blockEnd);

    if (keyword == '@keyframes' || keyword == '@-webkit-keyframes') {
      out.write(atRuleHeader);
      out.write('{');
      out.write(blockContent);
      out.write('}');
    } else if (keyword == '@font-face' ||
        keyword == '@page' ||
        keyword == '@property') {
      out.write(atRuleHeader);
      out.write('{');
      out.write(blockContent);
      out.write('}');
    } else {
      out.write(atRuleHeader);
      out.write('{');
      out.write(_parseStylesheet(blockContent));
      out.write('}');
    }

    return blockEnd + 1;
  }

  int _findNextRuleOpenBrace(String input, int start) {
    final len = input.length;
    var j = start;
    var inString = 0;
    var inComment = false;
    var bracketDepth = 0;
    var parenDepth = 0;

    while (j < len) {
      final c = input.codeUnitAt(j);
      if (inComment) {
        if (j + 1 < len && input[j] == '*' && input[j + 1] == '/') {
          inComment = false;
          j += 2;
          continue;
        }
        j++;
        continue;
      }
      if (j + 1 < len && input[j] == '/' && input[j + 1] == '*') {
        inComment = true;
        j += 2;
        continue;
      }
      if (inString != 0) {
        if (c == 92 && j + 1 < len) {
          j += 2;
          continue;
        }
        if (c == inString) inString = 0;
        j++;
        continue;
      }
      if (c == 34 || c == 39) {
        inString = c;
        j++;
        continue;
      }
      if (c == 91) {
        bracketDepth++;
        j++;
        continue;
      }
      if (c == 93) {
        if (bracketDepth > 0) bracketDepth--;
        j++;
        continue;
      }
      if (c == 40) {
        parenDepth++;
        j++;
        continue;
      }
      if (c == 41) {
        if (parenDepth > 0) parenDepth--;
        j++;
        continue;
      }
      if (bracketDepth == 0 && parenDepth == 0 && c == 123) {
        return j;
      }
      j++;
    }
    return -1;
  }

  int _findMatchingClosingBrace(String input, int openBraceIndex) {
    final len = input.length;
    var j = openBraceIndex + 1;
    var depth = 1;
    var inString = 0;
    var inComment = false;

    while (j < len) {
      final c = input.codeUnitAt(j);
      if (inComment) {
        if (j + 1 < len && input[j] == '*' && input[j + 1] == '/') {
          inComment = false;
          j += 2;
          continue;
        }
        j++;
        continue;
      }
      if (j + 1 < len && input[j] == '/' && input[j + 1] == '*') {
        inComment = true;
        j += 2;
        continue;
      }
      if (inString != 0) {
        if (c == 92 && j + 1 < len) {
          j += 2;
          continue;
        }
        if (c == inString) inString = 0;
        j++;
        continue;
      }
      if (c == 34 || c == 39) {
        inString = c;
        j++;
        continue;
      }
      if (c == 123) {
        depth++;
        j++;
        continue;
      }
      if (c == 125) {
        depth--;
        if (depth == 0) return j;
        j++;
        continue;
      }
      j++;
    }
    return -1;
  }

  String _rewriteSelectorList(String raw) {
    final parts = _splitSelectorList(raw);
    final rewritten = parts.map(_rewriteSingleSelector).toList();
    return rewritten.join(',');
  }

  List<String> _splitSelectorList(String raw) {
    final list = <String>[];
    final len = raw.length;
    var start = 0;
    var j = 0;
    var inString = 0;
    var inComment = false;
    var bracketDepth = 0;
    var parenDepth = 0;

    while (j < len) {
      final c = raw.codeUnitAt(j);
      if (inComment) {
        if (j + 1 < len && raw[j] == '*' && raw[j + 1] == '/') {
          inComment = false;
          j += 2;
          continue;
        }
        j++;
        continue;
      }
      if (j + 1 < len && raw[j] == '/' && raw[j + 1] == '*') {
        inComment = true;
        j += 2;
        continue;
      }
      if (inString != 0) {
        if (c == 92 && j + 1 < len) {
          j += 2;
          continue;
        }
        if (c == inString) inString = 0;
        j++;
        continue;
      }
      if (c == 34 || c == 39) {
        inString = c;
        j++;
        continue;
      }
      if (c == 91) {
        bracketDepth++;
        j++;
        continue;
      }
      if (c == 93) {
        if (bracketDepth > 0) bracketDepth--;
        j++;
        continue;
      }
      if (c == 40) {
        parenDepth++;
        j++;
        continue;
      }
      if (c == 41) {
        if (parenDepth > 0) parenDepth--;
        j++;
        continue;
      }
      if (c == 44 /* , */ && bracketDepth == 0 && parenDepth == 0) {
        list.add(raw.substring(start, j));
        start = j + 1;
      }
      j++;
    }
    list.add(raw.substring(start));
    return list;
  }

  String _rewriteSingleSelector(String selector) {
    final out = StringBuffer();
    final len = selector.length;
    var i = 0;

    while (i < len) {
      // 1. Comments
      if (i + 1 < len && selector[i] == '/' && selector[i + 1] == '*') {
        final end = selector.indexOf('*/', i + 2);
        if (end == -1) {
          out.write(selector.substring(i));
          break;
        } else {
          out.write(selector.substring(i, end + 2));
          i = end + 2;
          continue;
        }
      }

      // 2. Strings
      if (selector[i] == '"' || selector[i] == '\'') {
        final quote = selector[i];
        out.write(quote);
        i++;
        while (i < len) {
          final c = selector[i];
          out.write(c);
          if (c == '\\' && i + 1 < len) {
            out.write(selector[i + 1]);
            i += 2;
            continue;
          }
          if (c == quote) {
            i++;
            break;
          }
          i++;
        }
        continue;
      }

      // 3. Attribute selectors [...]
      if (selector[i] == '[') {
        final end = _findMatchingBracket(selector, i);
        if (end == -1) {
          out.write(selector.substring(i));
          break;
        } else {
          out.write(selector.substring(i, end + 1));
          i = end + 1;
          continue;
        }
      }

      // 4. :global(...) escape hatch
      if (selector.startsWith(':global(', i)) {
        final openParen = i + 7;
        final closeParen = _findMatchingParen(selector, openParen);
        if (closeParen == -1) {
          out.write(selector.substring(i));
          break;
        } else {
          final globalContent = selector.substring(openParen + 1, closeParen);
          out.write(globalContent);
          i = closeParen + 1;
          continue;
        }
      }

      // 5. Class selector .class
      if (selector[i] == '.' &&
          i + 1 < len &&
          _isIdentStart(selector.codeUnitAt(i + 1))) {
        final className = _readClassIdentifier(selector, i + 1);
        final scopedName = _getScopedClassName(className);
        out.write('.');
        out.write(scopedName);
        i += 1 + className.length;
        continue;
      }

      out.write(selector[i]);
      i++;
    }

    return out.toString();
  }

  int _findMatchingBracket(String str, int openIndex) {
    final len = str.length;
    var j = openIndex + 1;
    var depth = 1;
    var inString = 0;

    while (j < len) {
      final c = str.codeUnitAt(j);
      if (inString != 0) {
        if (c == 92 && j + 1 < len) {
          j += 2;
          continue;
        }
        if (c == inString) inString = 0;
        j++;
        continue;
      }
      if (c == 34 || c == 39) {
        inString = c;
        j++;
        continue;
      }
      if (c == 91) {
        depth++;
        j++;
        continue;
      }
      if (c == 93) {
        depth--;
        if (depth == 0) return j;
        j++;
        continue;
      }
      j++;
    }
    return -1;
  }

  int _findMatchingParen(String str, int openIndex) {
    final len = str.length;
    var j = openIndex + 1;
    var depth = 1;
    var inString = 0;

    while (j < len) {
      final c = str.codeUnitAt(j);
      if (inString != 0) {
        if (c == 92 && j + 1 < len) {
          j += 2;
          continue;
        }
        if (c == inString) inString = 0;
        j++;
        continue;
      }
      if (c == 34 || c == 39) {
        inString = c;
        j++;
        continue;
      }
      if (c == 40) {
        depth++;
        j++;
        continue;
      }
      if (c == 41) {
        depth--;
        if (depth == 0) return j;
        j++;
        continue;
      }
      j++;
    }
    return -1;
  }

  String _readClassIdentifier(String str, int start) {
    final len = str.length;
    var j = start;
    while (j < len) {
      if (str[j] == '\\' && j + 1 < len) {
        j += 2;
        continue;
      }
      final code = str.codeUnitAt(j);
      if (_isIdentChar(code)) {
        j++;
      } else {
        break;
      }
    }
    return str.substring(start, j);
  }
}
