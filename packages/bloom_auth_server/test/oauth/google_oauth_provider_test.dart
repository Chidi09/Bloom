import 'dart:convert';
import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const testClientId = 'google-client-id-123.apps.googleusercontent.com';
  const testClientSecret = 'GOCSPX-test-client-secret-456';
  const testRedirectUri = 'https://example.com/api/auth/google/callback';
  const testState = 'secure-csrf-state-token';

  group('GoogleOAuthProvider - constructor & URL building', () {
    test('rejects empty clientId or clientSecret', () {
      expect(
        () => GoogleOAuthProvider(clientId: '', clientSecret: testClientSecret),
        throwsArgumentError,
      );
      expect(
        () => GoogleOAuthProvider(clientId: testClientId, clientSecret: ''),
        throwsArgumentError,
      );
    });

    test(
        'buildAuthorizationUrl constructs valid Google OAuth2 URL with defaults',
        () {
      final provider = GoogleOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
      );

      final uri = provider.buildAuthorizationUrl(
        redirectUri: testRedirectUri,
        state: testState,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'accounts.google.com');
      expect(uri.path, '/o/oauth2/v2/auth');
      expect(uri.queryParameters['response_type'], 'code');
      expect(uri.queryParameters['client_id'], testClientId);
      expect(uri.queryParameters['redirect_uri'], testRedirectUri);
      expect(uri.queryParameters['state'], testState);
      expect(uri.queryParameters['scope'], 'openid email profile');
      expect(uri.queryParameters['access_type'], 'offline');
    });

    test('buildAuthorizationUrl respects custom scopes and prompt options', () {
      final provider = GoogleOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        prompt: 'consent select_account',
      );

      final uri = provider.buildAuthorizationUrl(
        redirectUri: testRedirectUri,
        state: testState,
        scopes: ['openid', 'https://www.googleapis.com/auth/calendar.readonly'],
      );

      expect(
        uri.queryParameters['scope'],
        'openid https://www.googleapis.com/auth/calendar.readonly',
      );
      expect(uri.queryParameters['prompt'], 'consent select_account');
    });

    test('buildAuthorizationUrl throws on empty redirectUri or state', () {
      final provider = GoogleOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
      );

      expect(
        () => provider.buildAuthorizationUrl(redirectUri: '', state: testState),
        throwsArgumentError,
      );
      expect(
        () => provider.buildAuthorizationUrl(
            redirectUri: testRedirectUri, state: ''),
        throwsArgumentError,
      );
    });
  });

  group('GoogleOAuthProvider - exchangeCode', () {
    test('exchanges code for tokens successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://oauth2.googleapis.com/token');
        expect(
          request.headers['content-type'],
          contains('application/x-www-form-urlencoded'),
        );
        expect(request.headers['accept'], contains('application/json'));

        final body = Uri.splitQueryString(request.body);
        expect(body['code'], 'auth-code-xyz');
        expect(body['client_id'], testClientId);
        expect(body['client_secret'], testClientSecret);
        expect(body['redirect_uri'], testRedirectUri);
        expect(body['grant_type'], 'authorization_code');

        return http.Response(
          jsonEncode({
            'access_token': 'ya29.a0AfH6SMB_sample_google_token',
            'token_type': 'Bearer',
            'expires_in': 3599,
            'refresh_token': '1//0gSampleRefreshToken',
            'scope': 'openid email profile',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final provider = GoogleOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      final tokenResponse = await provider.exchangeCode(
        code: 'auth-code-xyz',
        redirectUri: testRedirectUri,
      );

      expect(tokenResponse.accessToken, 'ya29.a0AfH6SMB_sample_google_token');
      expect(tokenResponse.tokenType, 'Bearer');
      expect(tokenResponse.expiresIn, 3599);
      expect(tokenResponse.refreshToken, '1//0gSampleRefreshToken');
      expect(tokenResponse.scope, 'openid email profile');
    });

    test('throws BloomOAuthException when Google returns an error payload',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Bad Request: Code has expired',
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GoogleOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      expect(
        () => provider.exchangeCode(
          code: 'expired-code',
          redirectUri: testRedirectUri,
        ),
        throwsA(
          isA<BloomOAuthException>()
              .having((e) => e.provider, 'provider', 'google')
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                  (e) => e.message, 'message', contains('Code has expired')),
        ),
      );
    });

    test(
        'throws BloomOAuthException when response is malformed HTML or non-JSON',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '<html><body>502 Bad Gateway</body></html>',
          502,
          headers: {'content-type': 'text/html'},
        );
      });

      final provider = GoogleOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      expect(
        () => provider.exchangeCode(
          code: 'any-code',
          redirectUri: testRedirectUri,
        ),
        throwsA(
          isA<BloomOAuthException>()
              .having((e) => e.provider, 'provider', 'google')
              .having((e) => e.statusCode, 'statusCode', 502),
        ),
      );
    });
  });

  group('GoogleOAuthProvider - fetchUserProfile', () {
    test('fetches and parses Google user profile correctly', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(),
            'https://www.googleapis.com/oauth2/v3/userinfo');
        expect(request.headers['authorization'], 'Bearer sample-access-token');

        return http.Response(
          jsonEncode({
            'sub': '108294729184918237000',
            'name': 'Alex Rivera',
            'given_name': 'Alex',
            'family_name': 'Rivera',
            'picture': 'https://lh3.googleusercontent.com/a/sample-avatar.png',
            'email': 'alex.rivera@example.com',
            'email_verified': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GoogleOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      final profile = await provider.fetchUserProfile('sample-access-token');

      expect(profile.provider, 'google');
      expect(profile.providerUserId, '108294729184918237000');
      expect(profile.email, 'alex.rivera@example.com');
      expect(profile.displayName, 'Alex Rivera');
      expect(profile.avatarUrl,
          'https://lh3.googleusercontent.com/a/sample-avatar.png');
      expect(profile.rawProfile['email_verified'], true);
    });

    test('throws BloomOAuthException when user profile request returns 401',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_token',
            'error_description': 'Invalid Credentials',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GoogleOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      expect(
        () => provider.fetchUserProfile('expired-or-invalid-token'),
        throwsA(
          isA<BloomOAuthException>()
              .having((e) => e.provider, 'provider', 'google')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('throws BloomOAuthException when subject claim is missing', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'name': 'Nameless User',
            'email': 'no-sub@example.com',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GoogleOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      expect(
        () => provider.fetchUserProfile('valid-token'),
        throwsA(
          isA<BloomOAuthException>()
              .having((e) => e.provider, 'provider', 'google')
              .having((e) => e.message, 'message', contains('missing subject')),
        ),
      );
    });
  });
}
