// lib/src/oauth/github_oauth_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'oauth_provider.dart';

/// GitHub OAuth2 Authorization Code flow provider implementation.
///
/// Integrates with GitHub's OAuth2 API endpoints:
/// - **Authorization Endpoint**: `https://github.com/login/oauth/authorize`
/// - **Token Endpoint**: `https://github.com/login/oauth/access_token`
/// - **User Profile Endpoint**: `https://api.github.com/user`
/// - **User Emails Endpoint**: `https://api.github.com/user/emails`
///
/// Handles multi-step email resolution to ensure primary verified email addresses
/// are retrieved even when users keep their email address private on GitHub.
///
/// Example:
/// ```dart
/// final github = GitHubOAuthProvider(
///   clientId: 'github-oauth-app-client-id',
///   clientSecret: 'github-oauth-app-client-secret',
/// );
///
/// final authUrl = github.buildAuthorizationUrl(
///   redirectUri: 'https://example.com/api/auth/github/callback',
///   state: 'csrf-protection-state-value',
/// );
/// ```
class GitHubOAuthProvider implements BloomOAuthProvider {
  /// GitHub OAuth App Client ID.
  final String clientId;

  /// GitHub OAuth App Client Secret.
  final String clientSecret;

  /// Default OAuth scopes requested when not specified in [buildAuthorizationUrl].
  final List<String> defaultScopes;

  /// Custom User-Agent header value sent with GitHub API requests.
  final String userAgent;

  final http.Client _client;

  /// GitHub OAuth2 authorization endpoint URL.
  static const String authorizationEndpoint =
      'https://github.com/login/oauth/authorize';

  /// GitHub OAuth2 token exchange endpoint URL.
  static const String tokenEndpoint =
      'https://github.com/login/oauth/access_token';

  /// GitHub REST API user endpoint URL.
  static const String userEndpoint = 'https://api.github.com/user';

  /// GitHub REST API user emails endpoint URL.
  static const String userEmailsEndpoint = 'https://api.github.com/user/emails';

  /// Creates a [GitHubOAuthProvider] instance.
  ///
  /// [clientId] and [clientSecret] are required.
  /// An optional [client] can be injected for test mocking (defaults to [http.Client]).
  GitHubOAuthProvider({
    required this.clientId,
    required this.clientSecret,
    http.Client? client,
    this.defaultScopes = const ['read:user', 'user:email'],
    this.userAgent = 'Bloom-OAuth-Client',
  }) : _client = client ?? http.Client() {
    if (clientId.isEmpty) {
      throw ArgumentError.value(clientId, 'clientId', 'GitHub clientId cannot be empty');
    }
    if (clientSecret.isEmpty) {
      throw ArgumentError.value(
        clientSecret,
        'clientSecret',
        'GitHub clientSecret cannot be empty',
      );
    }
  }

  @override
  String get name => 'github';

  @override
  Uri buildAuthorizationUrl({
    required String redirectUri,
    required String state,
    List<String>? scopes,
  }) {
    if (redirectUri.isEmpty) {
      throw ArgumentError.value(
        redirectUri,
        'redirectUri',
        'redirectUri cannot be empty',
      );
    }
    if (state.isEmpty) {
      throw ArgumentError.value(state, 'state', 'state parameter cannot be empty');
    }

    final effectiveScopes = scopes ?? defaultScopes;
    final queryParameters = <String, String>{
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': effectiveScopes.join(' '),
      'state': state,
    };

    return Uri.parse(authorizationEndpoint).replace(
      queryParameters: queryParameters,
    );
  }

  @override
  Future<BloomOAuthTokenResponse> exchangeCode({
    required String code,
    required String redirectUri,
  }) async {
    if (code.isEmpty) {
      throw ArgumentError.value(code, 'code', 'Authorization code cannot be empty');
    }
    if (redirectUri.isEmpty) {
      throw ArgumentError.value(
        redirectUri,
        'redirectUri',
        'redirectUri cannot be empty',
      );
    }

    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse(tokenEndpoint),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': userAgent,
        },
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'redirect_uri': redirectUri,
        },
      );
    } catch (e, st) {
      throw BloomOAuthException(
        'Failed to connect to GitHub token endpoint: $e',
        provider: name,
        cause: st,
      );
    }

    Map<String, dynamic> bodyJson;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        bodyJson = decoded;
      } else if (decoded is Map) {
        bodyJson = Map<String, dynamic>.from(decoded);
      } else {
        throw const FormatException('Expected JSON map object');
      }
    } catch (e) {
      throw BloomOAuthException(
        'GitHub token endpoint returned non-JSON response (HTTP ${response.statusCode})',
        provider: name,
        statusCode: response.statusCode,
        responseBody: response.body,
        cause: e,
      );
    }

    // GitHub returns HTTP 200 with `error` key on OAuth exchange failures
    if (response.statusCode != 200 || bodyJson.containsKey('error')) {
      final errorDescription = bodyJson['error_description']?.toString() ??
          bodyJson['error']?.toString() ??
          'Unknown GitHub OAuth token error';
      throw BloomOAuthException(
        'GitHub token exchange failed: $errorDescription',
        provider: name,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final tokenResponse = BloomOAuthTokenResponse.fromJson(bodyJson);
    if (tokenResponse.accessToken.isEmpty) {
      throw BloomOAuthException(
        'GitHub token response missing access_token',
        provider: name,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return tokenResponse;
  }

  @override
  Future<BloomOAuthUserProfile> fetchUserProfile(String accessToken) async {
    if (accessToken.isEmpty) {
      throw ArgumentError.value(
        accessToken,
        'accessToken',
        'accessToken cannot be empty',
      );
    }

    final authHeaders = {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      'User-Agent': userAgent,
    };

    final http.Response userResponse;
    try {
      userResponse = await _client.get(
        Uri.parse(userEndpoint),
        headers: authHeaders,
      );
    } catch (e, st) {
      throw BloomOAuthException(
        'Failed to fetch GitHub user profile: $e',
        provider: name,
        cause: st,
      );
    }

    Map<String, dynamic> userJson;
    try {
      final decoded = jsonDecode(userResponse.body);
      if (decoded is Map<String, dynamic>) {
        userJson = decoded;
      } else if (decoded is Map) {
        userJson = Map<String, dynamic>.from(decoded);
      } else {
        throw const FormatException('Expected JSON map object');
      }
    } catch (e) {
      throw BloomOAuthException(
        'GitHub user endpoint returned non-JSON response (HTTP ${userResponse.statusCode})',
        provider: name,
        statusCode: userResponse.statusCode,
        responseBody: userResponse.body,
        cause: e,
      );
    }

    if (userResponse.statusCode != 200) {
      final errorDescription = userJson['message']?.toString() ??
          'Failed to retrieve GitHub user profile';
      throw BloomOAuthException(
        'GitHub profile retrieval failed: $errorDescription',
        provider: name,
        statusCode: userResponse.statusCode,
        responseBody: userResponse.body,
      );
    }

    final id = userJson['id']?.toString();
    if (id == null || id.isEmpty) {
      throw BloomOAuthException(
        'GitHub user payload missing user "id"',
        provider: name,
        statusCode: userResponse.statusCode,
        responseBody: userResponse.body,
      );
    }

    String? email = userJson['email']?.toString();
    final nameStr = userJson['name']?.toString() ?? userJson['login']?.toString();
    final avatarUrl = userJson['avatar_url']?.toString();

    // If email is not public on /user profile, query /user/emails
    if (email == null || email.trim().isEmpty) {
      email = await _fetchPrimaryVerifiedEmail(authHeaders);
    }

    return BloomOAuthUserProfile(
      provider: name,
      providerUserId: id,
      email: email,
      displayName: nameStr,
      avatarUrl: avatarUrl,
      rawProfile: Map.unmodifiable(userJson),
    );
  }

  /// Queries GitHub's `/user/emails` endpoint to find the primary verified email address.
  Future<String?> _fetchPrimaryVerifiedEmail(
    Map<String, String> headers,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(userEmailsEndpoint),
        headers: headers,
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;

      String? firstVerified;
      String? fallbackFirst;

      for (final item in decoded) {
        if (item is! Map) continue;
        final emailStr = item['email']?.toString();
        if (emailStr == null || emailStr.isEmpty) continue;

        fallbackFirst ??= emailStr;

        final isVerified = item['verified'] == true;
        final isPrimary = item['primary'] == true;

        if (isPrimary && isVerified) {
          return emailStr;
        }

        if (isVerified && firstVerified == null) {
          firstVerified = emailStr;
        }
      }

      return firstVerified ?? fallbackFirst;
    } catch (_) {
      // Gracefully fall back to null email if /user/emails fails
      return null;
    }
  }
}
