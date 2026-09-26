// lib/src/format/css_formatter.dart

/// A lightweight, focused CSS pretty-printer that normalizes whitespace,
/// indentation, brace style, and semicolons without modifying property names,
/// values, selectors, or comments.
///
/// Designed specifically for Bloom's embedded CSS pattern:
/// - Top-level `const fooCss = r'''...''';` declarations
/// - Positional raw strings passed to `Style(r'''...''')`
String formatCss(String rawCss) {
  if (rawCss.trim().isEmpty) return rawCss;

  final leadingNewline = rawCss.startsWith('\n');
  final trailingNewline = rawCss.endsWith('\n');

  final tokens = _tokenize(rawCss);
  if (tokens.isEmpty) return rawCss;

  final nodes = _parseCss(tokens);
  final buffer = StringBuffer();
  _printNodes(nodes, buffer, indentLevel: 0, isTopLevel: true);

  var result = buffer.toString().trim();
  if (leadingNewline) result = '\n$result';
  if (trailingNewline) result = '$result\n';
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tokenizer
// ─────────────────────────────────────────────────────────────────────────────

enum _TokenType {
  comment,
  lbrace,
  rbrace,
  semicolon,
  text,
}

class _Token {
  final _TokenType type;
  final String text;
  final bool hasLeadingWhitespace;

  const _Token(this.type, this.text, {this.hasLeadingWhitespace = false});

  @override
  String toString() => 'Token($type, "$text", ws=$hasLeadingWhitespace)';
}

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var i = 0;
  final len = source.length;
  var hadWhitespace = false;

  while (i < len) {
    final char = source[i];

    // Comments: /* ... */
    if (char == '/' && i + 1 < len && source[i + 1] == '*') {
      final end = source.indexOf('*/', i + 2);
      if (end == -1) {
        tokens.add(_Token(
          _TokenType.comment,
          source.substring(i),
          hasLeadingWhitespace: hadWhitespace,
        ));
        break;
      } else {
        tokens.add(_Token(
          _TokenType.comment,
          source.substring(i, end + 2),
          hasLeadingWhitespace: hadWhitespace,
        ));
        i = end + 2;
        hadWhitespace = false;
        continue;
      }
    }

    // Whitespace tracking
    if (char == ' ' || char == '\t' || char == '\r' || char == '\n') {
      hadWhitespace = true;
      i++;
      continue;
    }

    final currentHadWs = hadWhitespace;
    hadWhitespace = false;

    // Structural characters
    if (char == '{') {
      tokens.add(
          _Token(_TokenType.lbrace, '{', hasLeadingWhitespace: currentHadWs));
      i++;
      continue;
    }
    if (char == '}') {
      tokens.add(
          _Token(_TokenType.rbrace, '}', hasLeadingWhitespace: currentHadWs));
      i++;
      continue;
    }
    if (char == ';') {
      tokens.add(_Token(_TokenType.semicolon, ';',
          hasLeadingWhitespace: currentHadWs));
      i++;
      continue;
    }

    // Combinators and delimiters as individual tokens when encountered standalone
    if (char == '>' ||
        char == '+' ||
        char == '~' ||
        char == ',' ||
        char == ':') {
      tokens.add(
          _Token(_TokenType.text, char, hasLeadingWhitespace: currentHadWs));
      i++;
      continue;
    }

    // Strings: "..." or '...'
    if (char == '"' || char == "'") {
      final quote = char;
      var j = i + 1;
      while (j < len) {
        if (source[j] == '\\') {
          j += 2;
        } else if (source[j] == quote) {
          j++;
          break;
        } else {
          j++;
        }
      }
      tokens.add(_Token(_TokenType.text, source.substring(i, j.clamp(0, len)),
          hasLeadingWhitespace: currentHadWs));
      i = j;
      continue;
    }

    // Parenthesized content (e.g. url(...), calc(...), (prefers-color-scheme: dark))
    if (char == '(') {
      var depth = 1;
      var j = i + 1;
      while (j < len && depth > 0) {
        if (source[j] == '(') {
          depth++;
          j++;
        } else if (source[j] == ')') {
          depth--;
          j++;
        } else if (source[j] == '"' || source[j] == "'") {
          final q = source[j];
          j++;
          while (j < len) {
            if (source[j] == '\\') {
              j += 2;
            } else if (source[j] == q) {
              j++;
              break;
            } else {
              j++;
            }
          }
        } else {
          j++;
        }
      }
      tokens.add(_Token(_TokenType.text, source.substring(i, j.clamp(0, len)),
          hasLeadingWhitespace: currentHadWs));
      i = j;
      continue;
    }

    // Brackets: [data-theme="dark"]
    if (char == '[') {
      var j = i + 1;
      while (j < len && source[j] != ']') {
        if (source[j] == '"' || source[j] == "'") {
          final q = source[j];
          j++;
          while (j < len) {
            if (source[j] == '\\') {
              j += 2;
            } else if (source[j] == q) {
              j++;
              break;
            } else {
              j++;
            }
          }
        } else {
          j++;
        }
      }
      if (j < len && source[j] == ']') j++;
      tokens.add(_Token(_TokenType.text, source.substring(i, j.clamp(0, len)),
          hasLeadingWhitespace: currentHadWs));
      i = j;
      continue;
    }

    // General text / word
    var j = i;
    while (j < len) {
      final c = source[j];
      if (c == '{' ||
          c == '}' ||
          c == ';' ||
          c == '(' ||
          c == '[' ||
          c == '"' ||
          c == "'" ||
          c == '>' ||
          c == '+' ||
          c == '~' ||
          c == ',' ||
          c == ':' ||
          c == ' ' ||
          c == '\t' ||
          c == '\r' ||
          c == '\n') {
        break;
      }
      if (c == '/' && j + 1 < len && source[j + 1] == '*') {
        break;
      }
      j++;
    }
    if (j > i) {
      tokens.add(_Token(_TokenType.text, source.substring(i, j),
          hasLeadingWhitespace: currentHadWs));
      i = j;
    } else {
      i++;
    }
  }

  return tokens;
}

// ─────────────────────────────────────────────────────────────────────────────
// AST Nodes & Parser
// ─────────────────────────────────────────────────────────────────────────────

abstract class _CssNode {}

class _CssCommentNode extends _CssNode {
  final String comment;
  _CssCommentNode(this.comment);
}

class _CssDeclarationNode extends _CssNode {
  final String property;
  final String value;
  _CssDeclarationNode(this.property, this.value);
}

class _CssRuleNode extends _CssNode {
  final String header;
  final List<_CssNode> children;
  _CssRuleNode(this.header, this.children);
}

class _CssAtStatementNode extends _CssNode {
  final String statement;
  _CssAtStatementNode(this.statement);
}

List<_CssNode> _parseCss(List<_Token> tokens) {
  final iterator = _TokenIterator(tokens);
  return _parseNodeList(iterator, isTopLevel: true);
}

class _TokenIterator {
  final List<_Token> tokens;
  int index = 0;

  _TokenIterator(this.tokens);

  bool get hasNext => index < tokens.length;
  _Token get current => tokens[index];
  _Token advance() => tokens[index++];
  _Token? peek([int offset = 0]) {
    final i = index + offset;
    if (i >= 0 && i < tokens.length) return tokens[i];
    return null;
  }
}

List<_CssNode> _parseNodeList(_TokenIterator it, {required bool isTopLevel}) {
  final nodes = <_CssNode>[];
  final pendingTokens = <_Token>[];

  while (it.hasNext) {
    final token = it.current;

    if (token.type == _TokenType.comment) {
      if (pendingTokens.isNotEmpty) {
        _flushPending(pendingTokens, nodes);
      }
      nodes.add(_CssCommentNode(it.advance().text));
      continue;
    }

    if (token.type == _TokenType.rbrace) {
      if (!isTopLevel) {
        // End of current block
        if (pendingTokens.isNotEmpty) {
          _flushPending(pendingTokens, nodes);
        }
        it.advance(); // consume '}'
        return nodes;
      }
      it.advance();
      continue;
    }

    if (token.type == _TokenType.lbrace) {
      it.advance(); // consume '{'
      final header = _tokensToSelectorText(pendingTokens);
      pendingTokens.clear();
      final children = _parseNodeList(it, isTopLevel: false);
      nodes.add(_CssRuleNode(header, children));
      continue;
    }

    if (token.type == _TokenType.semicolon) {
      it.advance(); // consume ';'
      _flushPending(pendingTokens, nodes);
      continue;
    }

    pendingTokens.add(it.advance());
  }

  if (pendingTokens.isNotEmpty) {
    _flushPending(pendingTokens, nodes);
  }

  return nodes;
}

void _flushPending(List<_Token> tokens, List<_CssNode> nodes) {
  if (tokens.isEmpty) return;

  var colonIndex = -1;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.text == ':') {
      colonIndex = i;
      break;
    } else if (t.text.startsWith(':') && !t.text.startsWith('::')) {
      // e.g. text token started with colon if any
      colonIndex = i;
      break;
    }
  }

  if (colonIndex != -1) {
    final propTokens = tokens.sublist(0, colonIndex);
    final valTokens = tokens.sublist(colonIndex + 1);
    final prop = _tokensToDeclarationText(propTokens).trim();
    final val = _tokensToDeclarationText(valTokens).trim();
    tokens.clear();
    if (prop.isNotEmpty || val.isNotEmpty) {
      nodes.add(_CssDeclarationNode(prop, val));
    }
  } else {
    final text = _tokensToSelectorText(tokens);
    tokens.clear();
    if (text.trim().isEmpty) return;
    if (text.startsWith('@')) {
      nodes.add(_CssAtStatementNode(text.trim()));
    } else {
      nodes.add(_CssDeclarationNode(text.trim(), ''));
    }
  }
}

String _tokensToDeclarationText(List<_Token> tokens) {
  final buffer = StringBuffer();
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (i > 0 && t.hasLeadingWhitespace) {
      buffer.write(' ');
    }
    buffer.write(t.text);
  }
  return buffer.toString().trim();
}

String _tokensToSelectorText(List<_Token> tokens) {
  final buffer = StringBuffer();
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (i > 0) {
      final prev = tokens[i - 1];
      if (_needsSpaceBetweenSelectorTokens(prev, t)) {
        buffer.write(' ');
      }
    }
    buffer.write(t.text);
  }
  return buffer.toString().trim();
}

bool _needsSpaceBetweenSelectorTokens(_Token prev, _Token next) {
  // Combinators require spaces around them
  if (prev.text == '>' || prev.text == '+' || prev.text == '~') return true;
  if (next.text == '>' || next.text == '+' || next.text == '~') return true;
  if (prev.text == ',') return true;
  if (next.text == ',') return false;

  // Between words / classes / attributes / pseudo-classes
  // Emit space iff source had whitespace there
  if (next.hasLeadingWhitespace) {
    return true;
  }

  return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Semantic Normalization & Safety Net
// ─────────────────────────────────────────────────────────────────────────────

/// Produces a semantically normalized form of [css] for safety comparison:
/// Collapses whitespace runs to a single space, then removes spaces adjacent
/// to `{`, `}`, `;`, `:`, `,`, `>`, `+`, `~`, `(`, `)` only where they are not
/// significant.
String normalizeCssSemantics(String css) {
  final sb = StringBuffer();
  var inString = false;
  var quoteChar = '';
  final len = css.length;
  var i = 0;

  // First pass: strip comments and normalize whitespace outside strings
  while (i < len) {
    final c = css[i];

    if (!inString && c == '/' && i + 1 < len && css[i + 1] == '*') {
      // Skip comment
      final end = css.indexOf('*/', i + 2);
      if (end == -1) {
        break;
      }
      i = end + 2;
      // Comments act like whitespace
      if (sb.isNotEmpty && !sb.toString().endsWith(' ')) {
        sb.write(' ');
      }
      continue;
    }

    if (!inString && (c == '"' || c == "'")) {
      inString = true;
      quoteChar = c;
      sb.write(c);
      i++;
      continue;
    }

    if (inString) {
      sb.write(c);
      if (c == '\\' && i + 1 < len) {
        i++;
        sb.write(css[i]);
      } else if (c == quoteChar) {
        inString = false;
      }
      i++;
      continue;
    }

    // Outside string / comment
    if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
      if (sb.isNotEmpty && !sb.toString().endsWith(' ')) {
        sb.write(' ');
      }
      i++;
      continue;
    }

    sb.write(c);
    i++;
  }

  final collapsed = sb.toString().trim();
  // Second pass: remove spaces around non-significant punctuation
  final out = StringBuffer();
  inString = false;
  quoteChar = '';

  bool isPunct(String ch) =>
      ch == '{' ||
      ch == '}' ||
      ch == ';' ||
      ch == ':' ||
      ch == ',' ||
      ch == '>' ||
      ch == '+' ||
      ch == '~' ||
      ch == '(' ||
      ch == ')';

  for (var j = 0; j < collapsed.length; j++) {
    final c = collapsed[j];

    if (!inString && (c == '"' || c == "'")) {
      inString = true;
      quoteChar = c;
      out.write(c);
      continue;
    }

    if (inString) {
      out.write(c);
      if (c == '\\' && j + 1 < collapsed.length) {
        j++;
        out.write(collapsed[j]);
      } else if (c == quoteChar) {
        inString = false;
      }
      continue;
    }

    if (c == ' ') {
      final prevChar = j > 0 ? collapsed[j - 1] : '';
      final nextChar = j + 1 < collapsed.length ? collapsed[j + 1] : '';

      if (isPunct(prevChar) || isPunct(nextChar)) {
        // Space adjacent to punct is insignificant, skip it
        continue;
      }
      out.write(' ');
      continue;
    }

    out.write(c);
  }

  return out.toString().trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Printer
// ─────────────────────────────────────────────────────────────────────────────

void _printNodes(
  List<_CssNode> nodes,
  StringBuffer buffer, {
  required int indentLevel,
  required bool isTopLevel,
}) {
  final indent = '  ' * indentLevel;

  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];

    if (isTopLevel && i > 0) {
      // Single blank line between top-level rules/comments
      buffer.writeln();
    }

    if (node is _CssCommentNode) {
      final lines = node.comment.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          buffer.writeln('$indent$trimmed');
        }
      }
    } else if (node is _CssDeclarationNode) {
      if (node.value.isNotEmpty) {
        buffer.writeln('$indent${node.property}: ${node.value};');
      } else {
        buffer.writeln('$indent${node.property};');
      }
    } else if (node is _CssAtStatementNode) {
      buffer.writeln('$indent${node.statement};');
    } else if (node is _CssRuleNode) {
      buffer.writeln('$indent${node.header} {');
      _printNodes(
        node.children,
        buffer,
        indentLevel: indentLevel + 1,
        isTopLevel: false,
      );
      buffer.writeln('$indent}');
    }
  }
}
