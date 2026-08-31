import 'dart:convert';
import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const testSigningSecret = 'test-secret-at-least-32-characters-long-oauth';

  setUp(() {
    BloomEnv.loadMap({
      'BLOOM_AUTH_SECRET': testSigningSecret,
    }, overwrite: true);
  });

  group('generateOAuthState', () {
    test('generates secure URL-safe random string', () {
      final state1 = generateOAuthState();
      final state2 = generateOAuthState();

      expect(state1, isNotEmpty);
      expect(state2, isNotEmpty);
      expect(state1, isNot(equals(state2)));
      // Base64url unpadded characters only
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(state1), isTrue);
    });

    test('rejects entropy length less than 16 bytes', () {
      expect(() => generateOAuthState(bytesCount: 15), throwsArgumentError);
    });
  });

  group('BloomOAuthFlow', () {
    test('buildAuthorizationUrl delegates to underlying provider', () {
      final provider = GoogleOAuthProvider(
        clientId: 'mock-google-client-id',
        clientSecret: 'mock-google-client-secret',
      );
      final flow = BloomOAuthFlow(provider);

      final uri = flow.buildAuthorizationUrl(
        redirectUri: 'https://example.com/callback',
        state: 'test-state-123',
      );

      expect(uri.host, 'accounts.google.com');
      expect(uri.queryParameters['client_id'], 'mock-google-client-id');
      expect(uri.queryParameters['state'], 'test-state-123');
    });

    test('exchangeAndFetchProfile orchestrates token and profile retrieval',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/token') {
          return http.Response(
            jsonEncode({
              'access_token': 'mock-access-token-123',
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/o/oauth2/v2/auth') {
          return http.Response('', 200);
        }
        if (request.url.path == '/oauth2/v3/userinfo') {
          return http.Response(
            jsonEncode({
              'sub': 'usr-google-999',
              'name': 'Taylor Swift',
              'email': 'taylor@example.com',
              'picture': 'https://example.com/avatar.jpg',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final provider = GoogleOAuthProvider(
        clientId: 'mock-id',
        clientSecret: 'mock-secret',
        client: mockClient,
      );
      final flow = BloomOAuthFlow(provider);

      final (:tokenResponse, :profile) = await flow.exchangeAndFetchProfile(
        code: 'auth-code-123',
        redirectUri: 'https://example.com/callback',
      );

      expect(tokenResponse.accessToken, 'mock-access-token-123');
      expect(profile.provider, 'google');
      expect(profile.providerUserId, 'usr-google-999');
      expect(profile.email, 'taylor@example.com');
      expect(profile.displayName, 'Taylor Swift');
    });

    test(
        'handleCallback completes end-to-end flow and issues verified JWT session token',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/token') {
          return http.Response(
            jsonEncode({
              'access_token': 'mock-token-abc',
              'token_type': 'Bearer',
              'expires_in': 7200,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/oauth2/v3/userinfo') {
          return http.Response(
            jsonEncode({
              'sub': 'google-uid-888',
              'name': 'Sam Developer',
              'email': 'sam@example.com',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final provider = GoogleOAuthProvider(
        clientId: 'mock-id',
        clientSecret: 'mock-secret',
        client: mockClient,
      );
      final flow = BloomOAuthFlow(provider);

      final now = DateTime.now().toUtc();
      final result = await flow.handleCallback(
        code: 'valid-auth-code',
        redirectUri: 'https://example.com/callback',
        resolveUser: (profile) async {
          expect(profile.provider, 'google');
          expect(profile.providerUserId, 'google-uid-888');
          expect(profile.email, 'sam@example.com');

          // Simulate database user lookup/creation
          return BloomAuthClaims(
            userId: 'local_db_user_123',
            email: profile.email,
            roles: const ['user', 'editor'],
            issuedAt: now,
            expiresAt: now.add(const Duration(days: 7)),
            customClaims: const {'orgId': 'org_bloom_01'},
          );
        },
      );

      // Verify returned result metadata
      expect(result.profile.provider, 'google');
      expect(result.profile.providerUserId, 'google-uid-888');
      expect(result.claims.userId, 'local_db_user_123');
      expect(result.claims.email, 'sam@example.com');
      expect(result.claims.roles, containsAll(['user', 'editor']));
      expect(result.sessionToken, isNotEmpty);

      // Verify the issued JWT session token using Bloom's standard verification
      final verifiedClaims = verifySessionToken(
        result.sessionToken,
        secret: testSigningSecret,
      );

      expect(verifiedClaims.userId, 'local_db_user_123');
      expect(verifiedClaims.email, 'sam@example.com');
      expect(verifiedClaims.roles, containsAll(['user', 'editor']));
      expect(verifiedClaims.customClaims['orgId'], 'org_bloom_01');
    });

    test('handleCallback respects custom secret and issuer parameters',
        () async {
      const customSecret = 'custom-signing-secret-key-32-chars-long';
      const customIssuer = 'my-custom-auth-service';

      final mockClient = MockClient((request) async {
        if (request.url.path == '/token') {
          return http.Response(
            jsonEncode({'access_token': 'token-123'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/oauth2/v3/userinfo') {
          return http.Response(
            jsonEncode({'sub': 'google-777', 'email': 'custom@example.com'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final flow = BloomOAuthFlow(
        GoogleOAuthProvider(
          clientId: 'id',
          clientSecret: 'secret',
          client: mockClient,
        ),
      );

      final now = DateTime.now().toUtc();
      final result = await flow.handleCallback(
        code: 'code',
        redirectUri: 'https://example.com/callback',
        secret: customSecret,
        issuer: customIssuer,
        resolveUser: (profile) => BloomAuthClaims(
          userId: 'user_777',
          email: profile.email,
          issuedAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );

      // Verifying with default secret should fail
      expect(
        () => verifySessionToken(result.sessionToken),
        throwsA(isA<SessionTokenException>()),
      );

      // Verifying with customSecret and customIssuer should succeed
      final verified = verifySessionToken(
        result.sessionToken,
        secret: customSecret,
        issuer: customIssuer,
      );
      expect(verified.userId, 'user_777');
    });

    test(
        'stateStore integration: generates, saves, verifies, and consumes single-use state',
        () async {
      final stateStore = InMemoryOAuthStateStore();
      final mockClient = MockClient((request) async {
        if (request.url.path == '/token') {
          return http.Response(
            jsonEncode({'access_token': 'token-xyz'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/oauth2/v3/userinfo') {
          return http.Response(
            jsonEncode({'sub': 'google-456', 'email': 'state@example.com'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final flow = BloomOAuthFlow(
        GoogleOAuthProvider(
          clientId: 'id',
          clientSecret: 'secret',
          client: mockClient,
        ),
        stateStore: stateStore,
      );

      final state = await flow.generateAndSaveState();
      expect(state, isNotEmpty);
      expect(stateStore.count, 1);

      final now = DateTime.now().toUtc();

      // 1. Missing state when store configured throws BloomOAuthStateException
      expect(
        () => flow.handleCallback(
          code: 'code-1',
          redirectUri: 'https://example.com/callback',
          resolveUser: (p) =>
              BloomAuthClaims(userId: 'u', issuedAt: now, expiresAt: now),
        ),
        throwsA(isA<BloomOAuthStateException>()),
      );

      // 2. Invalid state throws BloomOAuthStateException
      expect(
        () => flow.handleCallback(
          code: 'code-1',
          redirectUri: 'https://example.com/callback',
          state: 'invalid-state-token',
          resolveUser: (p) =>
              BloomAuthClaims(userId: 'u', issuedAt: now, expiresAt: now),
        ),
        throwsA(isA<BloomOAuthStateException>()),
      );

      // 3. Valid state succeeds and consumes the token
      final result = await flow.handleCallback(
        code: 'code-1',
        redirectUri: 'https://example.com/callback',
        state: state,
        resolveUser: (p) => BloomAuthClaims(
          userId: 'user_state_success',
          email: p.email,
          issuedAt: now,
          expiresAt: now.add(const Duration(days: 1)),
        ),
      );
      expect(result.claims.userId, 'user_state_success');
      expect(stateStore.count, 0);

      // 4. Replaying the same state token is rejected (single-use CSRF defense)
      expect(
        () => flow.handleCallback(
          code: 'code-1',
          redirectUri: 'https://example.com/callback',
          state: state,
          resolveUser: (p) =>
              BloomAuthClaims(userId: 'u', issuedAt: now, expiresAt: now),
        ),
        throwsA(isA<BloomOAuthStateException>()),
      );
    });
  });
}
