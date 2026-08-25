// lib/src/template.dart
import 'dart:io';

/// Wrapper designating a raw HTML string as safe from escaping.
class SafeHtml {
  /// The unescaped HTML content.
  final String rawHtml;

  /// Creates a [SafeHtml] wrapper.
  const SafeHtml(this.rawHtml);

  @override
  String toString() => rawHtml;
}

/// Escapes special HTML characters (`&`, `<`, `>`, `"`, `'`, `/`) for XSS prevention.
String htmlEscape(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    switch (char) {
      case '&':
        buffer.write('&amp;');
        break;
      case '<':
        buffer.write('&lt;');
        break;
      case '>':
        buffer.write('&gt;');
        break;
      case '"':
        buffer.write('&quot;');
        break;
      case "'":
        buffer.write('&#x27;');
        break;
      case '/':
        buffer.write('&#x2F;');
        break;
      default:
        buffer.write(char);
    }
  }
  return buffer.toString();
}

/// A Django-inspired transactional email template engine.
///
/// Supports:
/// - Variable interpolation: `{{ user.name }}` with nested dot property navigation.
/// - Safe escaping: Automatic HTML escaping for HTML templates, bypassable via `{{ var | safe }}` or [SafeHtml].
/// - Template filters: `| safe`, `| raw`, `| upper`, `| lower`, `| trim`, `| length`, `| default:"fallback"`.
/// - Conditionals: `{% if user.is_admin %}` ... `{% elif user.is_staff %}` ... `{% else %}` ... `{% endif %}`.
/// - Logical and comparison operators: `==`, `!=`, `<`, `<=`, `>`, `>=`, `and`, `or`, `not`.
/// - Loops: `{% for item in items %}` ... `{% empty %}` ... `{% endfor %}` with `forloop.index`, `forloop.first`, etc.
/// - Comments: `{# comment #}` or `{% comment %}` ... `{% endcomment %}`.
/// - Companion plain-text templates alongside HTML templates.
class BloomMailTemplate {
  /// Raw template source content.
  final String source;

  /// Whether this template is HTML-formatted and variables should be HTML-escaped by default.
  final bool isHtml;

  /// Optional companion plain-text template for multipart email delivery.
  final BloomMailTemplate? textTemplate;

  /// Optional filesystem path if loaded from disk.
  final String? filePath;

  final List<_Node> _parsedNodes;

  /// Creates a [BloomMailTemplate] from raw [source].
  BloomMailTemplate(
    this.source, {
    this.isHtml = true,
    this.textTemplate,
    this.filePath,
  }) : _parsedNodes = _parseTemplate(source);

  /// Loads an HTML template from a raw [source] string, with an optional companion [textSource].
  factory BloomMailTemplate.fromString(
    String source, {
    bool isHtml = true,
    String? textSource,
    BloomMailTemplate? textTemplate,
  }) {
    final companion = textTemplate ??
        (textSource != null
            ? BloomMailTemplate(textSource, isHtml: false)
            : null);
    return BloomMailTemplate(
      source,
      isHtml: isHtml,
      textTemplate: companion,
    );
  }

  /// Convenience factory for creating a plain-text template from [source].
  factory BloomMailTemplate.text(String source) {
    return BloomMailTemplate(source, isHtml: false);
  }

  /// Convenience factory for creating an HTML template from [source] with an optional [textTemplate].
  factory BloomMailTemplate.html(
    String source, {
    BloomMailTemplate? textTemplate,
    String? textSource,
  }) {
    final companion = textTemplate ??
        (textSource != null
            ? BloomMailTemplate(textSource, isHtml: false)
            : null);
    return BloomMailTemplate(source, isHtml: true, textTemplate: companion);
  }

  /// Loads a template from a [File] on disk.
  ///
  /// If [textFile] is not provided and [isHtml] is true, checks for a companion
  /// plain-text file on disk by replacing `.html`/`.htm` with `.txt` (e.g. `welcome.html` -> `welcome.txt`).
  factory BloomMailTemplate.fromFile(
    File file, {
    bool isHtml = true,
    File? textFile,
    bool autoDetectTextCompanion = true,
  }) {
    final content = file.readAsStringSync();
    BloomMailTemplate? companion;

    if (textFile != null) {
      if (textFile.existsSync()) {
        companion = BloomMailTemplate(
          textFile.readAsStringSync(),
          isHtml: false,
          filePath: textFile.path,
        );
      }
    } else if (isHtml && autoDetectTextCompanion) {
      final companionPath = _resolveCompanionTextPath(file.path);
      if (companionPath != null) {
        final companionFile = File(companionPath);
        if (companionFile.existsSync()) {
          companion = BloomMailTemplate(
            companionFile.readAsStringSync(),
            isHtml: false,
            filePath: companionFile.path,
          );
        }
      }
    }

    return BloomMailTemplate(
      content,
      isHtml: isHtml,
      textTemplate: companion,
      filePath: file.path,
    );
  }

  /// Loads a template from a filesystem [path].
  ///
  /// If [textPath] is not provided and [isHtml] is true, checks for a companion
  /// plain-text file on disk by replacing `.html`/`.htm` with `.txt`.
  factory BloomMailTemplate.fromPath(
    String path, {
    bool isHtml = true,
    String? textPath,
    bool autoDetectTextCompanion = true,
  }) {
    return BloomMailTemplate.fromFile(
      File(path),
      isHtml: isHtml,
      textFile: textPath != null ? File(textPath) : null,
      autoDetectTextCompanion: autoDetectTextCompanion,
    );
  }

  /// Creates a paired template combining an [html] template and an optional [text] template.
  factory BloomMailTemplate.paired({
    required BloomMailTemplate html,
    BloomMailTemplate? text,
  }) {
    return BloomMailTemplate(
      html.source,
      isHtml: true,
      textTemplate: text ?? html.textTemplate,
      filePath: html.filePath,
    );
  }

  /// Helper to resolve companion text file path from an HTML path.
  static String? _resolveCompanionTextPath(String htmlPath) {
    if (htmlPath.endsWith('.html')) {
      return '${htmlPath.substring(0, htmlPath.length - 5)}.txt';
    } else if (htmlPath.endsWith('.htm')) {
      return '${htmlPath.substring(0, htmlPath.length - 4)}.txt';
    }
    return null;
  }

  /// Renders this template with the given data [context] map.
  ///
  /// Missing variables evaluate to empty strings (`""`) without throwing exceptions.
  String render(Map<String, dynamic> context) {
    final buffer = StringBuffer();
    for (final node in _parsedNodes) {
      node.render(buffer, context, isHtml);
    }
    return buffer.toString();
  }

  /// Renders the companion plain-text template if present, or `null`.
  String? renderText(Map<String, dynamic> context) {
    if (textTemplate != null) {
      return textTemplate!.render(context);
    }
    if (!isHtml) {
      return render(context);
    }
    return null;
  }

  /// Returns a copy of this template with a companion [textTemplate] attached.
  BloomMailTemplate withTextCompanion(BloomMailTemplate textTemplate) {
    return BloomMailTemplate(
      source,
      isHtml: isHtml,
      textTemplate: textTemplate,
      filePath: filePath,
    );
  }

  @override
  String toString() {
    return 'BloomMailTemplate(isHtml: $isHtml, hasTextCompanion: ${textTemplate != null}, length: ${source.length})';
  }
}

/// Alias for [BloomMailTemplate].
typedef MailTemplate = BloomMailTemplate;

// ---------------------------------------------------------------------------
// Internal Tokenizer & AST Parser
// ---------------------------------------------------------------------------

sealed class _Token {}

class _TextToken extends _Token {
  final String text;
  _TextToken(this.text);
}

class _VarToken extends _Token {
  final String expression;
  final List<String> filters;
  _VarToken(this.expression, this.filters);
}

class _TagToken extends _Token {
  final String name;
  final String args;
  final String raw;
  _TagToken(this.name, this.args, this.raw);
}

class _CommentToken extends _Token {
  final String text;
  _CommentToken(this.text);
}

List<_Token> _tokenize(String template) {
  final tokens = <_Token>[];
  final pattern = RegExp(r'(\{\{.*?\}\}|\{%.*?%\}|\{#.*?#\})', dotAll: true);
  var lastEnd = 0;

  for (final match in pattern.allMatches(template)) {
    if (match.start > lastEnd) {
      tokens.add(_TextToken(template.substring(lastEnd, match.start)));
    }

    final raw = match.group(0)!;
    if (raw.startsWith('{#') && raw.endsWith('#}')) {
      final content = raw.substring(2, raw.length - 2).trim();
      tokens.add(_CommentToken(content));
    } else if (raw.startsWith('{{') && raw.endsWith('}}')) {
      final content = raw.substring(2, raw.length - 2).trim();
      final filterParts = content.split('|');
      final expr = filterParts[0].trim();
      final filters = <String>[];
      for (var i = 1; i < filterParts.length; i++) {
        final f = filterParts[i].trim();
        if (f.isNotEmpty) {
          filters.add(f);
        }
      }
      tokens.add(_VarToken(expr, filters));
    } else if (raw.startsWith('{%') && raw.endsWith('%}')) {
      final content = raw.substring(2, raw.length - 2).trim();
      final spaceIndex = content.indexOf(RegExp(r'\s'));
      final tagName = spaceIndex == -1 ? content : content.substring(0, spaceIndex).trim();
      final tagArgs = spaceIndex == -1 ? '' : content.substring(spaceIndex).trim();
      tokens.add(_TagToken(tagName, tagArgs, raw));
    }

    lastEnd = match.end;
  }

  if (lastEnd < template.length) {
    tokens.add(_TextToken(template.substring(lastEnd)));
  }

  return tokens;
}

List<_Node> _parseTemplate(String source) {
  final tokens = _tokenize(source);
  final parser = _TemplateParser(tokens);
  return parser.parseBlock();
}

sealed class _Node {
  void render(StringBuffer buffer, Map<String, dynamic> context, bool isHtml);
}

class _TextNode extends _Node {
  final String text;
  _TextNode(this.text);

  @override
  void render(StringBuffer buffer, Map<String, dynamic> context, bool isHtml) {
    buffer.write(text);
  }
}

class _VarNode extends _Node {
  final String expression;
  final List<String> filters;

  _VarNode(this.expression, this.filters);

  @override
  void render(StringBuffer buffer, Map<String, dynamic> context, bool isHtml) {
    var val = _evalExpression(expression, context);
    var isSafe = false;

    if (val is SafeHtml) {
      isSafe = true;
      val = val.rawHtml;
    }

    for (final rawFilter in filters) {
      final filter = rawFilter.trim();
      if (filter == 'safe' || filter == 'raw') {
        isSafe = true;
      } else if (filter == 'upper') {
        val = val?.toString().toUpperCase();
      } else if (filter == 'lower') {
        val = val?.toString().toLowerCase();
      } else if (filter == 'trim') {
        val = val?.toString().trim();
      } else if (filter == 'length') {
        if (val is String) {
          val = val.length;
        } else if (val is Iterable) {
          val = val.length;
        } else if (val is Map) {
          val = val.length;
        } else {
          val = 0;
        }
      } else if (filter.startsWith('default:')) {
        final defVal = _stripQuotes(filter.substring(8).trim());
        if (val == null ||
            val == '' ||
            (val is Iterable && val.isEmpty) ||
            (val is Map && val.isEmpty)) {
          val = defVal;
        }
      }
    }

    if (val == null) {
      return;
    }

    final str = val.toString();
    if (isHtml && !isSafe) {
      buffer.write(htmlEscape(str));
    } else {
      buffer.write(str);
    }
  }
}

class _IfBranch {
  final String condition;
  final List<_Node> body;

  _IfBranch(this.condition, this.body);
}

class _IfNode extends _Node {
  final List<_IfBranch> branches;
  final List<_Node>? elseBody;

  _IfNode(this.branches, this.elseBody);

  @override
  void render(StringBuffer buffer, Map<String, dynamic> context, bool isHtml) {
    for (final branch in branches) {
      if (_evalCondition(branch.condition, context)) {
        for (final node in branch.body) {
          node.render(buffer, context, isHtml);
        }
        return;
      }
    }
    if (elseBody != null) {
      for (final node in elseBody!) {
        node.render(buffer, context, isHtml);
      }
    }
  }
}

class _ForNode extends _Node {
  final String args;
  final List<_Node> body;
  final List<_Node>? emptyBody;

  _ForNode(this.args, this.body, this.emptyBody);

  @override
  void render(StringBuffer buffer, Map<String, dynamic> context, bool isHtml) {
    final inIndex = args.indexOf(' in ');
    if (inIndex == -1) {
      if (emptyBody != null) {
        for (final node in emptyBody!) {
          node.render(buffer, context, isHtml);
        }
      }
      return;
    }

    final itemVar = args.substring(0, inIndex).trim();
    final iterableExpr = args.substring(inIndex + 4).trim();

    final iterableVal = _evalExpression(iterableExpr, context);
    Iterable<dynamic>? items;
    if (iterableVal is Iterable) {
      items = iterableVal;
    } else if (iterableVal is Map) {
      items = iterableVal.entries;
    }

    if (items == null || items.isEmpty) {
      if (emptyBody != null) {
        for (final node in emptyBody!) {
          node.render(buffer, context, isHtml);
        }
      }
      return;
    }

    final list = items.toList();
    final len = list.length;

    for (var i = 0; i < len; i++) {
      final item = list[i];
      final loopContext = Map<String, dynamic>.from(context);
      loopContext[itemVar] = item;
      loopContext['forloop'] = {
        'index': i + 1,
        'index0': i,
        'first': i == 0,
        'last': i == len - 1,
        'length': len,
        'counter': i + 1,
        'counter0': i,
        'revcounter': len - i,
        'revcounter0': len - i - 1,
      };

      for (final node in body) {
        node.render(buffer, loopContext, isHtml);
      }
    }
  }
}

class _TemplateParser {
  final List<_Token> tokens;
  int pos = 0;

  _TemplateParser(this.tokens);

  List<_Node> parseBlock({Set<String> stopTokens = const {}}) {
    final nodes = <_Node>[];
    while (pos < tokens.length) {
      final token = tokens[pos];
      if (token is _TagToken) {
        final tagName = token.name;
        if (stopTokens.contains(tagName)) {
          break;
        }
        pos++;
        if (tagName == 'if') {
          nodes.add(_parseIf(token));
        } else if (tagName == 'for') {
          nodes.add(_parseFor(token));
        } else if (tagName == 'comment') {
          _parseComment();
        } else {
          // Unknown or raw tag, output as literal text
          nodes.add(_TextNode(token.raw));
        }
      } else if (token is _VarToken) {
        pos++;
        nodes.add(_VarNode(token.expression, token.filters));
      } else if (token is _TextToken) {
        pos++;
        nodes.add(_TextNode(token.text));
      } else if (token is _CommentToken) {
        pos++;
        // Comments are ignored during rendering
      }
    }
    return nodes;
  }

  _IfNode _parseIf(_TagToken ifTag) {
    final branches = <_IfBranch>[];
    branches.add(_IfBranch(
      ifTag.args,
      parseBlock(stopTokens: {'elif', 'else if', 'else', 'endif'}),
    ));

    while (pos < tokens.length) {
      final token = tokens[pos];
      if (token is _TagToken) {
        if (token.name == 'elif' || token.name == 'else if') {
          pos++;
          branches.add(_IfBranch(
            token.args,
            parseBlock(stopTokens: {'elif', 'else if', 'else', 'endif'}),
          ));
        } else if (token.name == 'else') {
          pos++;
          final elseBody = parseBlock(stopTokens: {'endif'});
          if (pos < tokens.length &&
              tokens[pos] is _TagToken &&
              (tokens[pos] as _TagToken).name == 'endif') {
            pos++;
          }
          return _IfNode(branches, elseBody);
        } else if (token.name == 'endif') {
          pos++;
          return _IfNode(branches, null);
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return _IfNode(branches, null);
  }

  _ForNode _parseFor(_TagToken forTag) {
    final body = parseBlock(stopTokens: {'empty', 'endfor'});
    List<_Node>? emptyBody;

    if (pos < tokens.length && tokens[pos] is _TagToken) {
      final token = tokens[pos] as _TagToken;
      if (token.name == 'empty') {
        pos++;
        emptyBody = parseBlock(stopTokens: {'endfor'});
      }
    }

    if (pos < tokens.length &&
        tokens[pos] is _TagToken &&
        (tokens[pos] as _TagToken).name == 'endfor') {
      pos++;
    }

    return _ForNode(forTag.args, body, emptyBody);
  }

  void _parseComment() {
    while (pos < tokens.length) {
      final token = tokens[pos];
      pos++;
      if (token is _TagToken && token.name == 'endcomment') {
        break;
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Evaluator & Helper Functions
// ---------------------------------------------------------------------------

Object? _evalExpression(String expr, Map<String, dynamic> context) {
  final trimmed = expr.trim();
  if (trimmed.isEmpty) return null;

  // String literals
  if ((trimmed.startsWith("'") && trimmed.endsWith("'")) ||
      (trimmed.startsWith('"') && trimmed.endsWith('"'))) {
    if (trimmed.length >= 2) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return '';
  }

  // Numbers
  final intVal = int.tryParse(trimmed);
  if (intVal != null) return intVal;
  final doubleVal = double.tryParse(trimmed);
  if (doubleVal != null) return doubleVal;

  // Booleans & Null
  if (trimmed == 'true' || trimmed == 'True') return true;
  if (trimmed == 'false' || trimmed == 'False') return false;
  if (trimmed == 'null' || trimmed == 'None' || trimmed == 'nil') return null;

  return _lookup(trimmed, context);
}

Object? _lookup(String path, Map<String, dynamic> context) {
  if (path.isEmpty) return null;
  if (context.containsKey(path)) {
    return context[path];
  }

  final parts = path.split('.');
  Object? current = context;

  for (final part in parts) {
    final key = part.trim();
    if (current == null) return null;

    if (current is Map) {
      current = current[key];
    } else if (current is List) {
      final index = int.tryParse(key);
      if (index != null && index >= 0 && index < current.length) {
        current = current[index];
      } else {
        return null;
      }
    } else if (current is MapEntry) {
      if (key == 'key') {
        current = current.key;
      } else if (key == 'value') {
        current = current.value;
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  return current;
}

bool _evalCondition(String condition, Map<String, dynamic> context) {
  final trimmed = condition.trim();
  if (trimmed.isEmpty) return false;

  // Logical OR
  final orParts = _splitOutsideQuotes(trimmed, [' or ', ' || ']);
  if (orParts.length > 1) {
    for (final part in orParts) {
      if (_evalCondition(part, context)) {
        return true;
      }
    }
    return false;
  }

  // Logical AND
  final andParts = _splitOutsideQuotes(trimmed, [' and ', ' && ']);
  if (andParts.length > 1) {
    for (final part in andParts) {
      if (!_evalCondition(part, context)) {
        return false;
      }
    }
    return true;
  }

  // Single condition
  var single = trimmed;
  var isNegated = false;

  if (single.startsWith('not ') || single.startsWith('!')) {
    isNegated = true;
    single = single.startsWith('not ')
        ? single.substring(4).trim()
        : single.substring(1).trim();
  }

  // Check comparisons
  const operators = ['==', '!=', '<=', '>=', '<', '>'];
  for (final op in operators) {
    final opParts = _splitOutsideQuotes(single, [' $op ', op]);
    if (opParts.length == 2) {
      final leftVal = _evalExpression(opParts[0], context);
      final rightVal = _evalExpression(opParts[1], context);
      final compResult = _compare(leftVal, op, rightVal);
      return isNegated ? !compResult : compResult;
    }
  }

  final val = _evalExpression(single, context);
  final truthy = _isTruthy(val);
  return isNegated ? !truthy : truthy;
}

List<String> _splitOutsideQuotes(String input, List<String> delimiters) {
  for (final delim in delimiters) {
    var inSingleQuote = false;
    var inDoubleQuote = false;
    for (var i = 0; i <= input.length - delim.length; i++) {
      final char = input[i];
      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
      } else if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
      } else if (!inSingleQuote && !inDoubleQuote) {
        if (input.substring(i, i + delim.length) == delim) {
          final left = input.substring(0, i);
          final right = input.substring(i + delim.length);
          return [left, right];
        }
      }
    }
  }
  return [input];
}

bool _compare(Object? left, String op, Object? right) {
  if (op == '==') {
    if (left == right) return true;
    if (left != null && right != null && left.toString() == right.toString()) {
      return true;
    }
    return false;
  }
  if (op == '!=') {
    if (left == right) return false;
    if (left != null && right != null && left.toString() == right.toString()) {
      return false;
    }
    return true;
  }

  final leftNum = left is num ? left : num.tryParse(left?.toString() ?? '');
  final rightNum = right is num ? right : num.tryParse(right?.toString() ?? '');

  if (leftNum != null && rightNum != null) {
    switch (op) {
      case '<':
        return leftNum < rightNum;
      case '<=':
        return leftNum <= rightNum;
      case '>':
        return leftNum > rightNum;
      case '>=':
        return leftNum >= rightNum;
    }
  }

  if (left is Comparable && right is Comparable) {
    try {
      final c = (left as dynamic).compareTo(right);
      switch (op) {
        case '<':
          return c < 0;
        case '<=':
          return c <= 0;
        case '>':
          return c > 0;
        case '>=':
          return c >= 0;
      }
    } catch (_) {}
  }

  return false;
}

bool _isTruthy(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

String _stripQuotes(String s) {
  if ((s.startsWith("'") && s.endsWith("'")) ||
      (s.startsWith('"') && s.endsWith('"'))) {
    if (s.length >= 2) {
      return s.substring(1, s.length - 1);
    }
  }
  return s;
}
