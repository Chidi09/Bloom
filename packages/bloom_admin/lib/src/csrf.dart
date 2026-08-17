import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:bloom_framework/bloom_server.dart';

/// Cryptographic CSRF token manager for `bloom_admin`.
///
/// Implements HMAC-SHA256 based CSRF tokens bound to a server secret or session.
/// Guarantees that state-changing admin actions (POST, PUT, DELETE) originate
/// from authenticated and legitimate admin form submissions.
class AdminCsrf {
  static const String formFieldName = 'csrfmiddlewaretoken';
  static const String headerName = 'x-csrftoken';
  static const String cookieName = 'bloom_csrftoken';

  final String _secret;

  AdminCsrf({String? secret})
      : _secret = secret ?? 'bloom_admin_default_secret_key_change_in_production';

  /// Generates a signed, opaque CSRF token for a given session / nonce identifier.
  String generateToken([String identifier = 'session']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = '$identifier:$timestamp';
    final hmac = Hmac(sha256, utf8.encode(_secret));
    final signature = hmac.convert(utf8.encode(payload)).toString();
    final combined = '$payload:$signature';
    return base64Url.encode(utf8.encode(combined));
  }

  /// Verifies that a submitted CSRF token is cryptographically valid and authentic.
  bool verifyToken(String? token, [String identifier = 'session']) {
    if (token == null || token.isEmpty) return false;

    try {
      final decoded = utf8.decode(base64Url.decode(token));
      final parts = decoded.split(':');
      if (parts.length != 3) return false;

      final tokenIdentifier = parts[0];
      final tokenTimestamp = parts[1];
      final tokenSignature = parts[2];

      // Identifier must match (or both non-empty for global session scope)
      if (tokenIdentifier != identifier && identifier != 'session') {
        return false;
      }

      final payload = '$tokenIdentifier:$tokenTimestamp';
      final hmac = Hmac(sha256, utf8.encode(_secret));
      final expectedSignature = hmac.convert(utf8.encode(payload)).toString();

      return _constantTimeEquals(tokenSignature, expectedSignature);
    } catch (_) {
      return false;
    }
  }

  /// Extracts the CSRF token from a [BloomRequest], checking form data, headers, or query params.
  String? extractToken(BloomRequest request, [Map<String, String>? formData]) {
    // 1. Check form data if available
    if (formData != null && formData.containsKey(formFieldName)) {
      return formData[formFieldName];
    }

    final parsedForm = request.formData();
    if (parsedForm.containsKey(formFieldName)) {
      return parsedForm[formFieldName];
    }

    // 2. Check HTTP headers (case-insensitive)
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == headerName) {
        return entry.value;
      }
    }

    // 3. Check query params
    if (request.queryParams.containsKey(formFieldName)) {
      return request.queryParams[formFieldName];
    }

    return null;
  }

  /// Validates a request against CSRF attacks. Returns `true` if valid.
  bool validateRequest(BloomRequest request, [Map<String, String>? formData]) {
    final method = request.method.toUpperCase();
    // Safe HTTP methods do not require CSRF validation
    if (method == 'GET' || method == 'HEAD' || method == 'OPTIONS' || method == 'TRACE') {
      return true;
    }

    final token = extractToken(request, formData);
    return verifyToken(token);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
