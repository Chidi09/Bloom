import 'dart:convert';
import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const testClientId = 'github-client-id-abc';
  const testClientSecret = 'github-client-secret-def';
  const testRedirectUri = 'https://example.com/api/auth/github/callback';
  const testState = 'secure-csrf-state-token-gh';

  group('GitHubOAuthProvider - constructor & URL building', () {
    test('rejects empty clientId or clientSecret', () {
      expect(
        () => GitHubOAuthProvider(clientId: '', clientSecret: testClientSecret),
        throwsArgumentError,
      );
      expect(
        () => GitHubOAuthProvider(clientId: testClientId, clientSecret: ''),
        throwsArgumentError,
      );
    });

    test('buildAuthorizationUrl constructs valid GitHub OAuth URL with defaults', () {
      final provider = GitHubOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
      );

      final uri = provider.buildAuthorizationUrl(
        redirectUri: testRedirectUri,
        state: testState,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'github.com');
      expect(uri.path, '/login/oauth/authorize');
      expect(uri.queryParameters['client_id'], testClientId);
      expect(uri.queryParameters['redirect_uri'], testRedirectUri);
      expect(uri.queryParameters['state'], testState);
      expect(uri.queryParameters['scope'], 'read:user user:email');
    });

    test('buildAuthorizationUrl respects custom scopes', () {
      final provider = GitHubOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
      );

      final uri = provider.buildAuthorizationUrl(
        redirectUri: testRedirectUri,
        state: testState,
        scopes: ['repo', 'user:email'],
      );

      expect(uri.queryParameters['scope'], 'repo user:email');
    });

    test('buildAuthorizationUrl throws on empty redirectUri or state', () {
      final provider = GitHubOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
      );

      expect(
        () => provider.buildAuthorizationUrl(redirectUri: '', state: testState),
        throwsArgumentError,
      );
      expect(
        () => provider.buildAuthorizationUrl(redirectUri: testRedirectUri, state: ''),
        throwsArgumentError,
      );
    });
  });

  group('GitHubOAuthProvider - exchangeCode', () {
    test('exchanges code for tokens successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://github.com/login/oauth/access_token');
        expect(request.headers['accept'], 'application/json');
        expect(
          request.headers['content-type'],
          contains('application/x-www-form-urlencoded'),
        );
        expect(request.headers['user-agent'], 'Bloom-OAuth-Client');

        final body = Uri.splitQueryString(request.body);
        expect(body['code'], 'gh-code-123');
        expect(body['client_id'], testClientId);
        expect(body['client_secret'], testClientSecret);
        expect(body['redirect_uri'], testRedirectUri);

        return http.Response(
          jsonEncode({
            'access_token': 'gho_16C7eFe0XDJn0yRGVdnnhBUrUDW0rX4jBtg6',
            'token_type': 'bearer',
            'scope': 'read:user,user:email',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final provider = GitHubOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      final tokenResponse = await provider.exchangeCode(
        code: 'gh-code-123',
        redirectUri: testRedirectUri,
      );

      expect(
        tokenResponse.accessToken,
        'gho_16C7eFe0XDJn0yRGVdnnhBUrUDW0rX4jBtg6',
      );
      expect(tokenResponse.tokenType, 'bearer');
      expect(tokenResponse.scope, 'read:user,user:email');
    });

    test('throws BloomOAuthException when GitHub returns error object in JSON body', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'bad_verification_code',
            'error_description': 'The code passed is incorrect or expired.',
            'error_uri': 'https://docs.github.com/apps/managing-oauth-apps/...',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GitHubOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      expect(
        () => provider.exchangeCode(
          code: 'bad-code',
          redirectUri: testRedirectUri,
        ),
        throwsA(
          isA<BloomOAuthException>()
              .having((e) => e.provider, 'provider', 'github')
              .having((e) => e.message, 'message', contains('incorrect or expired')),
        ),
      );
    });

    test('throws BloomOAuthException on HTTP non-200 status', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Server Error'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GitHubOAuthProvider(
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
              .having((e) => e.provider, 'provider', 'github')
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  group('GitHubOAuthProvider - fetchUserProfile', () {
    test('fetches profile with public email from /user endpoint', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://api.github.com/user');
        expect(request.headers['authorization'], 'Bearer gho_test_token');
        expect(request.headers['user-agent'], 'Bloom-OAuth-Client');

        return http.Response(
          jsonEncode({
            'id': 583231,
            'login': 'octocat',
            'name': 'The Octocat',
            'avatar_url': 'https://avatars.githubusercontent.com/u/583231?v=4',
            'email': 'octocat@github.com',
            'bio': 'GitHub mascot',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GitHubOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      final profile = await provider.fetchUserProfile('gho_test_token');

      expect(profile.provider, 'github');
      expect(profile.providerUserId, '583231');
      expect(profile.email, 'octocat@github.com');
      expect(profile.displayName, 'The Octocat');
      expect(profile.avatarUrl, 'https://avatars.githubusercontent.com/u/583231?v=4');
      expect(profile.rawProfile['bio'], 'GitHub mascot');
    });

    test('fetches primary verified email from /user/emails when /user email is null', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/user') {
          return http.Response(
            jsonEncode({
              'id': 123456,
              'login': 'private-user',
              'name': 'Private Developer',
              'avatar_url': 'https://avatars.githubusercontent.com/u/123456',
              'email': null, // Email is private on public profile
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/user/emails') {
          expect(request.headers['authorization'], 'Bearer gho_test_token');
          expect(request.headers['user-agent'], 'Bloom-OAuth-Client');

          return http.Response(
            jsonEncode([
              {
                'email': 'noreply@github.com',
                'primary': false,
                'verified': true,
                'visibility': null,
              },
              {
                'email': 'primary.dev@example.org',
                'primary': true,
                'verified': true,
                'visibility': 'private',
              },
              {
                'email': 'unverified@example.org',
                'primary': false,
                'verified': false,
                'visibility': null,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final provider = GitHubOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      final profile = await provider.fetchUserProfile('gho_test_token');

      expect(profile.provider, 'github');
      expect(profile.providerUserId, '123456');
      expect(profile.email, 'primary.dev@example.org');
      expect(profile.displayName, 'Private Developer');
    });

    test('throws BloomOAuthException when user profile fails with 401', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Bad credentials'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GitHubOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      expect(
        () => provider.fetchUserProfile('invalid-token'),
        throwsA(
          isA<BloomOAuthException>()
              .having((e) => e.provider, 'provider', 'github')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('throws BloomOAuthException when id is missing from /user response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'login': 'no-id-user'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GitHubOAuthProvider(
        clientId: testClientId,
        clientSecret: testClientSecret,
        client: mockClient,
      );

      expect(
        () => provider.fetchUserProfile('valid-token'),
        throwsA(
          isA<BloomOAuthException>()
              .having((e) => e.provider, 'provider', 'github')
              .having((e) => e.message, 'message', contains('missing user "id"')),
        ),
      );
    });
  });
}
