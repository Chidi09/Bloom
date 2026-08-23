import 'dart:convert';

String encodeCursor(String id, String isoTime) {
  final payload = {'id': id, 't': isoTime};
  return base64Url.encode(utf8.encode(jsonEncode(payload)));
}

({String id, DateTime time})? decodeCursor(String raw) {
  try {
    var n = raw;
    while (n.length % 4 != 0) n += '=';
    final s = utf8.decode(base64Url.decode(n));
    final m = jsonDecode(s) as Map;
    final id = m['id']?.toString();
    final t = m['t']?.toString();
    if (id == null || t == null) return null;
    final dt = DateTime.tryParse(t);
    if (dt == null) return null;
    return (id: id, time: dt);
  } catch (_) {
    return null;
  }
}
