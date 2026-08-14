// test/api_routes_test.dart
import 'dart:convert';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_fullstack_api/routes/api/health.dart';
import 'package:bloom_fullstack_api/routes/api/users.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bloom Full-Stack: API Route Handlers', () {
    late BloomApiRouter router;

    setUp(() {
      router = BloomApiRouter();
      router.get('/api/health', handleHealth);
      router.get('/api/users', handleGetUsers);
      router.post('/api/users', handleCreateUser);
    });

    test('GET /api/health returns healthy JSON status', () async {
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/health'),
      );

      final res = await router.handle(req);
      expect(res.statusCode, 200);
      expect(res.headers['Content-Type'], contains('application/json'));

      final json = jsonDecode(utf8.decode(res.body)) as Map<String, dynamic>;
      expect(json['status'], 'healthy');
      expect(json['version'], '1.0.0');
    });

    test('GET /api/users returns list of users', () async {
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/users'),
      );

      final res = await router.handle(req);
      expect(res.statusCode, 200);

      final json = jsonDecode(utf8.decode(res.body)) as Map<String, dynamic>;
      expect(json['users'], isList);
      expect(json['count'], greaterThanOrEqualTo(2));
    });

    test('POST /api/users creates new user with 201 status', () async {
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/api/users'),
        headers: {'Content-Type': 'application/json'},
        body: utf8.encode(jsonEncode({'name': 'Ada Lovelace', 'role': 'Pioneer'})),
      );

      final res = await router.handle(req);
      expect(res.statusCode, 201);

      final json = jsonDecode(utf8.decode(res.body)) as Map<String, dynamic>;
      expect(json['name'], 'Ada Lovelace');
      expect(json['role'], 'Pioneer');
    });
  });
}
