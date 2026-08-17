/// Safe-by-default server-side HTML rendering engine for `bloom_admin`.
///
/// Every interpolated value is strictly HTML-escaped by default to prevent XSS.
/// Raw HTML can only be rendered if explicitly wrapped in [SafeHtml].
class SafeHtml {
  /// The unescaped, raw HTML payload.
  final String rawHtml;

  /// Creates a [SafeHtml] wrapper designating [rawHtml] as safe to render without escaping.
  const SafeHtml(this.rawHtml);


  @override
  String toString() => rawHtml;
}

/// Helper extension or function for HTML string escaping.
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

/// Base class for template evaluation and rendering.
abstract class AdminTemplate {
  /// Renders this template with a given [context] map.
  String render(Map<String, dynamic> context);
}
