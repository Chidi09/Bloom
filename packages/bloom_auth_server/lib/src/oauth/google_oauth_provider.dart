// lib/src/oauth/google_oauth_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'oauth_provider.dart';

/// Google OAuth2 Authorization Code flow provider implementation.
///
/// Integrates with Google Identity services using standard OpenID Connect / OAuth2 endpoints:
/// - **Authorization Endpoint**: `https://accounts.google.com/o/oauth2/v2/auth`
/// - **Token Endpoint**: `https://oauth2.googleapis.com/token`
/// - **User Profile Endpoint**: `https://www.googleapis.com/oauth2/v3/userinfo`
///
/// Supports customizable scopes, offline access tokens (`access_type=offline`),
/// and injectable [http.Client] for seamless unit and integration testing.
///
/// Example:
/// ```dart
/// final google = GoogleOAuthProvider(
///   clientId: 'google-client-id.apps.googleusercontent.com',
///   clientSecret: 'GOCSPX-google-client-secret',
/// );
///
/// final authUrl = google.buildAuthorizationUrl(
///   redirectUri: 'https://example.com/api/auth/google/callback',
///   state: 'csrf-protection-state-value',
/// );
/// ```
class GoogleOAuthProvider implements BloomOAuthProvider {
  /// Google OAuth2 Client ID obtained from Google Cloud Console.
  final String clientId;

  /// Google OAuth2 Client Secret obtained from Google Cloud Console.
  final String clientSecret;

  /// Default OAuth scopes requested when not specified in [buildAuthorizationUrl].
  final List<String> defaultScopes;

  /// Optional access type for Google OAuth consent screen (default `'offline'`).
  final String accessType;

  /// Optional prompt behavior for Google consent screen (e.g. `'consent'`, `'select_account'`).
  final String? prompt;

  final http.Client _client;

  /// Google OAuth2 authorization endpoint URL.
  static const String authorizationEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';

  /// Google OAuth2 token exchange endpoint URL.
  static const String tokenEndpoint = 'https://oauth2.googleapis.com/token';

  /// Google OpenID Connect UserInfo endpoint URL.
  static const String userInfoEndpoint =
      'https://www.googleapis.com/oauth2/v3/userinfo';

  /// Creates a [GoogleOAuthProvider] instance.
  ///
  /// [clientId] and [clientSecret] are required.
  /// An optional [client] can be injected for test mocking (defaults to [http.Client]).
  GoogleOAuthProvider({
    required this.clientId,
    required this.clientSecret,
    http.Client? client,
    this.defaultScopes = const ['openid', 'email', 'profile'],
    this.accessType = 'offline',
    this.prompt,
  }) : _client = client ?? http.Client() {
    if (clientId.isEmpty) {
      throw ArgumentError.value(
          clientId, 'clientId', 'Google clientId cannot be empty');
    }
    if (clientSecret.isEmpty) {
      throw ArgumentError.value(
        clientSecret,
        'clientSecret',
        'Google clientSecret cannot be empty',
      );
    }
  }

  @override
  String get name => 'google';

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
      throw ArgumentError.value(
          state, 'state', 'state parameter cannot be empty');
    }

    final effectiveScopes = scopes ?? defaultScopes;
    final queryParameters = <String, String>{
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': effectiveScopes.join(' '),
      'state': state,
      if (accessType.isNotEmpty) 'access_type': accessType,
      if (prompt != null && prompt!.isNotEmpty) 'prompt': prompt!,
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
      throw ArgumentError.value(
          code, 'code', 'Authorization code cannot be empty');
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
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'code': code,
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );
    } catch (e, st) {
      throw BloomOAuthException(
        'Failed to connect to Google token endpoint: $e',
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
        'Google token endpoint returned non-JSON response (HTTP ${response.statusCode})',
        provider: name,
        statusCode: response.statusCode,
        responseBody: response.body,
        cause: e,
      );
    }

    if (response.statusCode != 200) {
      final errorDescription = bodyJson['error_description']?.toString() ??
          bodyJson['error']?.toString() ??
          'Unknown Google OAuth token error';
      throw BloomOAuthException(
        'Google token exchange failed: $errorDescription',
        provider: name,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final tokenResponse = BloomOAuthTokenResponse.fromJson(bodyJson);
    if (tokenResponse.accessToken.isEmpty) {
      throw BloomOAuthException(
        'Google token response missing access_token',
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

    final http.Response response;
    try {
      response = await _client.get(
        Uri.parse(userInfoEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );
    } catch (e, st) {
      throw BloomOAuthException(
        'Failed to fetch Google user profile: $e',
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
        'Google userinfo endpoint returned non-JSON response (HTTP ${response.statusCode})',
        provider: name,
        statusCode: response.statusCode,
        responseBody: response.body,
        cause: e,
      );
    }

    if (response.statusCode != 200) {
      final errorDescription = bodyJson['error_description']?.toString() ??
          bodyJson['error']?.toString() ??
          'Failed to retrieve Google user profile';
      throw BloomOAuthException(
        'Google profile retrieval failed: $errorDescription',
        provider: name,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final sub = bodyJson['sub']?.toString();
    if (sub == null || sub.isEmpty) {
      throw BloomOAuthException(
        'Google userinfo payload missing subject ("sub") claim',
        provider: name,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final email = bodyJson['email']?.toString();
    final nameStr = bodyJson['name']?.toString();
    final picture = bodyJson['picture']?.toString();

    return BloomOAuthUserProfile(
      provider: name,
      providerUserId: sub,
      email: email,
      displayName: nameStr,
      avatarUrl: picture,
      rawProfile: Map.unmodifiable(bodyJson),
    );
  }
}
