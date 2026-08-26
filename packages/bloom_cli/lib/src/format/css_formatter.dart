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
  colon,
  comma,
  text,
}

class _Token {
  final _TokenType type;
  final String text;

  const _Token(this.type, this.text);

  @override
  String toString() => 'Token($type, "$text")';
}

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var i = 0;
  final len = source.length;

  while (i < len) {
    final char = source[i];

    // Comments: /* ... */
    if (char == '/' && i + 1 < len && source[i + 1] == '*') {
      final end = source.indexOf('*/', i + 2);
      if (end == -1) {
        tokens.add(_Token(_TokenType.comment, source.substring(i)));
        break;
      } else {
        tokens.add(_Token(_TokenType.comment, source.substring(i, end + 2)));
        i = end + 2;
        continue;
      }
    }

    // Skip whitespace
    if (char == ' ' || char == '\t' || char == '\r' || char == '\n') {
      i++;
      continue;
    }

    // Structural characters
    if (char == '{') {
      tokens.add(const _Token(_TokenType.lbrace, '{'));
      i++;
      continue;
    }
    if (char == '}') {
      tokens.add(const _Token(_TokenType.rbrace, '}'));
      i++;
      continue;
    }
    if (char == ';') {
      tokens.add(const _Token(_TokenType.semicolon, ';'));
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
      tokens.add(_Token(_TokenType.text, source.substring(i, j.clamp(0, len))));
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
      tokens.add(_Token(_TokenType.text, source.substring(i, j.clamp(0, len))));
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
      tokens.add(_Token(_TokenType.text, source.substring(i, j.clamp(0, len))));
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
      tokens.add(_Token(_TokenType.text, source.substring(i, j)));
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
      final header = _tokensToText(pendingTokens);
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

  final text = _tokensToText(tokens);
  tokens.clear();
  if (text.trim().isEmpty) return;

  // Check if declaration (has a colon separating property and value)
  final colonIndex = _findDeclarationColon(text);
  if (colonIndex != -1) {
    final prop = text.substring(0, colonIndex).trim();
    final val = text.substring(colonIndex + 1).trim();
    nodes.add(_CssDeclarationNode(prop, val));
  } else if (text.startsWith('@')) {
    nodes.add(_CssAtStatementNode(text.trim()));
  } else {
    // Other statement / custom property
    nodes.add(_CssDeclarationNode(text.trim(), ''));
  }
}

int _findDeclarationColon(String text) {
  var inQuote = false;
  var quoteChar = '';
  var parenDepth = 0;
  var bracketDepth = 0;

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuote) {
      if (c == '\\') {
        i++;
      } else if (c == quoteChar) {
        inQuote = false;
      }
      continue;
    }

    if (c == '"' || c == "'") {
      inQuote = true;
      quoteChar = c;
      continue;
    }

    if (c == '(') parenDepth++;
    if (c == ')') parenDepth--;
    if (c == '[') bracketDepth++;
    if (c == ']') bracketDepth--;

    if (c == ':' && parenDepth == 0 && bracketDepth == 0) {
      return i;
    }
  }

  return -1;
}

String _tokensToText(List<_Token> tokens) {
  final buffer = StringBuffer();
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (i > 0) {
      final prev = tokens[i - 1];
      // Keep selectors and properties cleanly spaced
      if (_needsSpaceBetween(prev, t)) {
        buffer.write(' ');
      }
    }
    buffer.write(t.text);
  }
  return buffer.toString().trim();
}

bool _needsSpaceBetween(_Token prev, _Token next) {
  if (prev.text == ':' && !prev.text.startsWith('::')) {
    // space after colon in declaration
    return true;
  }
  if (prev.text == ',') return true;
  if (next.text == ',' || next.text == ';' || next.text == ':') return false;
  if (prev.type == _TokenType.text && next.type == _TokenType.text) {
    // If next is a pseudo-class or pseudo-element attached to selector, no space
    if (next.text.startsWith(':') || next.text.startsWith('.')) {
      return false;
    }
    // If next is a parenthesized group (e.g. CSS function call or selector
    // pseudo-class argument), do not insert a space before '(', unless prev
    // is an at-rule keyword (e.g. @media (...), @supports (...)).
    if (next.text.startsWith('(')) {
      if (prev.text.startsWith('@')) {
        return true;
      }
      return false;
    }
    return true;
  }
  return false;
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
