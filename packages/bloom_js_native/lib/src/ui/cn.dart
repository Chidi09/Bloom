/// Plain Dart class name concatenation helper for Bloom UI primitives.
///
/// Combines class names, filtering out null, false, empty, or whitespace-only
/// entries, and joins them with a single space.
String cn(List<Object?> classes) {
  final buffer = StringBuffer();
  for (final item in classes) {
    if (item == null || item == false) continue;
    final str = item.toString().trim();
    if (str.isEmpty) continue;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(str);
  }
  return buffer.toString();
}
