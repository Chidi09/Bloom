// lib/src/dev/css_hot_swap.dart

/// Represents a detected CSS-only change between two versions of a Dart source file.
class CssOnlyChange {
  final String oldCss;
  final String newCss;

  const CssOnlyChange({
    required this.oldCss,
    required this.newCss,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CssOnlyChange &&
          runtimeType == other.runtimeType &&
          oldCss == other.oldCss &&
          newCss == other.newCss;

  @override
  int get hashCode => Object.hash(oldCss, newCss);

  @override
  String toString() =>
      'CssOnlyChange(oldCss: ${oldCss.length} chars, newCss: ${newCss.length} chars)';
}

final _rawStringRegex = RegExp(r"r'''(.*?)'''", dotAll: true);
final _styleCallRegex = RegExp(r'Style\s*\(\s*$');
final _constAssignRegex = RegExp(r'=\s*$');
final _constKeywordRegex = RegExp(r'\bconst\b');

/// Returns the (old, new) CSS text pair if [newSource] differs from
/// [oldSource] ONLY inside the body of a single CSS raw-string literal
/// (a top-level `const <name>Css = r'''...''';` declaration, or a
/// positional `Style(r'''...''')` argument). Returns null if the
/// change is not a pure single-CSS-literal edit (including: no raw
/// strings changed, more than one raw string's content differs, the
/// literal isn't recognizably CSS by the heuristic above, or any
/// non-string-literal text differs between the two sources).
CssOnlyChange? detectCssOnlyChange(String oldSource, String newSource) {
  if (oldSource == newSource) return null;

  // 1. Build skeletons by replacing every raw string literal body with empty placeholder.
  final oldSkeleton =
      oldSource.replaceAllMapped(_rawStringRegex, (m) => "r''''''");
  final newSkeleton =
      newSource.replaceAllMapped(_rawStringRegex, (m) => "r''''''");

  // 2. Skeletons must be character-for-character identical.
  if (oldSkeleton != newSkeleton) return null;

  // 3. Find and pair raw-string matches by ordinal position.
  final oldMatches = _rawStringRegex.allMatches(oldSource).toList();
  final newMatches = _rawStringRegex.allMatches(newSource).toList();
  if (oldMatches.length != newMatches.length || oldMatches.isEmpty) return null;

  // 4. Count differing literal bodies.
  int diffIndex = -1;
  int diffCount = 0;
  for (var i = 0; i < oldMatches.length; i++) {
    final oldBody = oldMatches[i].group(1)!;
    final newBody = newMatches[i].group(1)!;
    if (oldBody != newBody) {
      diffCount++;
      diffIndex = i;
    }
  }

  if (diffCount != 1) return null;

  // 5. Check CSS declaration heuristic on the changed literal.
  final match = newMatches[diffIndex];
  final prefix = newSource.substring(0, match.start);

  // (b) Positional argument immediately inside Style(...)
  final isInsideStyle = _styleCallRegex.hasMatch(prefix);

  // (a) Right-hand side of a `const ... = r'''...''';` declaration
  bool isConstDeclaration = false;
  if (!isInsideStyle) {
    var lastBoundary = -1;
    final lastSemicolon = prefix.lastIndexOf(';');
    final lastBrace = prefix.lastIndexOf('}');
    if (lastSemicolon > lastBoundary) lastBoundary = lastSemicolon;
    if (lastBrace > lastBoundary) lastBoundary = lastBrace;
    final stmtPrefix =
        lastBoundary >= 0 ? prefix.substring(lastBoundary + 1) : prefix;

    if (_constAssignRegex.hasMatch(stmtPrefix) &&
        _constKeywordRegex.hasMatch(stmtPrefix)) {
      isConstDeclaration = true;
    }
  }

  if (!isInsideStyle && !isConstDeclaration) {
    return null;
  }

  return CssOnlyChange(
    oldCss: oldMatches[diffIndex].group(1)!,
    newCss: newMatches[diffIndex].group(1)!,
  );
}
