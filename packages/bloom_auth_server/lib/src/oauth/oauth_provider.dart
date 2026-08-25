// lib/src/oauth/oauth_provider.dart
import 'dart:async';

/// Exception thrown when an OAuth2 authorization, token exchange, or profile fetch fails.
///
/// Encapsulates the provider name in [provider], optional HTTP [statusCode],
/// underlying [cause], and the raw response body in [responseBody].
///
/// Example:
/// ```dart
/// try {
///   final token = await provider.exchangeCode(code: code, redirectUri: redirectUri);
/// } on BloomOAuthException catch (e) {
///   print('OAuth failure (${e.provider}): ${e.message} [HTTP ${e.statusCode}]');
/// }
/// ```
class BloomOAuthException implements Exception {
  /// Description of the error.
  final String message;

  /// The OAuth provider identifier (e.g. `'google'`, `'github'`), if known.
  final String? provider;

  /// The HTTP status code received from the OAuth provider, if applicable.
  final int? statusCode;

  /// The underlying cause or exception, if any.
  final dynamic cause;

  /// The raw response body returned by the OAuth provider endpoint, if available.
  final String? responseBody;

  /// Creates a [BloomOAuthException] instance.
  const BloomOAuthException(
    this.message, {
    this.provider,
    this.statusCode,
    this.cause,
    this.responseBody,
  });

  @override
  String toString() =>
      'BloomOAuthException${provider != null ? ' ($provider)' : ''}: $message'
      '${statusCode != null ? ' [HTTP $statusCode]' : ''}'
      '${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Strongly-typed response received from an OAuth2 token exchange endpoint.
///
/// Encapsulates the bearer [accessToken], optional [refreshToken], token lifetime in [expiresIn],
/// token type in [tokenType] (typically `'Bearer'`), granted [scope], and unparsed provider
/// metadata in [rawData].
///
/// Example:
/// ```dart
/// final tokenResponse = await provider.exchangeCode(code: code, redirectUri: redirectUri);
/// print('Access token: ${tokenResponse.accessToken}');
/// print('Expires in: ${tokenResponse.expiresIn}s');
/// ```
class BloomOAuthTokenResponse {
  /// The OAuth2 access token used to authenticate requests to resource APIs.
  final String accessToken;

  /// Optional refresh token used to obtain new access tokens when expired.
  final String? refreshToken;

  /// The type of token issued (defaults to `'Bearer'`).
  final String tokenType;

  /// The lifetime duration of the access token in seconds, if provided by the provider.
  final int? expiresIn;

  /// The scope of access granted by the access token.
  final String? scope;

  /// Additional raw metadata returned by the provider's token endpoint.
  final Map<String, dynamic> rawData;

  /// Creates a [BloomOAuthTokenResponse] instance.
  const BloomOAuthTokenResponse({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
    this.scope,
    this.rawData = const {},
  });

  /// Factory constructor to parse token parameters from a JSON map [json].
  factory BloomOAuthTokenResponse.fromJson(Map<String, dynamic> json) {
    final rawExpiresIn = json['expires_in'];
    int? parsedExpiresIn;
    if (rawExpiresIn is num) {
      parsedExpiresIn = rawExpiresIn.toInt();
    } else if (rawExpiresIn is String) {
      parsedExpiresIn = int.tryParse(rawExpiresIn);
    }

    return BloomOAuthTokenResponse(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString(),
      tokenType: json['token_type']?.toString() ?? 'Bearer',
      expiresIn: parsedExpiresIn,
      scope: json['scope']?.toString(),
      rawData: Map.unmodifiable(json),
    );
  }

  /// Converts the token response into a JSON-serializable [Map].
  Map<String, dynamic> toMap() => {
        'access_token': accessToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
        'token_type': tokenType,
        if (expiresIn != null) 'expires_in': expiresIn,
        if (scope != null) 'scope': scope,
        ...rawData,
      };

  @override
  String toString() =>
      'BloomOAuthTokenResponse(tokenType: $tokenType, expiresIn: $expiresIn, scope: $scope)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomOAuthTokenResponse &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          tokenType == other.tokenType &&
          expiresIn == other.expiresIn &&
          scope == other.scope;

  @override
  int get hashCode =>
      Object.hash(accessToken, refreshToken, tokenType, expiresIn, scope);
}

/// Normalized user profile extracted from an OAuth2 provider's identity endpoint.
///
/// Encapsulates the identity [provider], the provider's unique [providerUserId], verified [email],
/// user's [displayName], and [avatarUrl], alongside the complete unparsed payload in [rawProfile].
///
/// Example:
/// ```dart
/// final profile = await provider.fetchUserProfile(tokenResponse.accessToken);
/// print('User: ${profile.displayName} (${profile.email})');
/// print('Provider ID: ${profile.provider}:${profile.providerUserId}');
/// ```
class BloomOAuthUserProfile {
  /// The identifier of the OAuth provider (e.g. `'google'`, `'github'`).
  final String provider;

  /// The unique, immutable user identifier assigned by the OAuth provider (e.g. Google `sub`, GitHub `id`).
  final String providerUserId;

  /// The user's primary email address, if available and verified.
  final String? email;

  /// The user's full name or handle (e.g. `'Alex Johnson'`).
  final String? displayName;

  /// URL pointing to the user's profile image / avatar.
  final String? avatarUrl;

  /// Unmodified raw profile JSON returned by the provider's userinfo endpoint.
  final Map<String, dynamic> rawProfile;

  /// Creates a [BloomOAuthUserProfile] instance.
  const BloomOAuthUserProfile({
    required this.provider,
    required this.providerUserId,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.rawProfile = const {},
  });

  /// Converts profile claims into a JSON-serializable [Map].
  Map<String, dynamic> toMap() => {
        'provider': provider,
        'providerUserId': providerUserId,
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        ...rawProfile,
      };

  @override
  String toString() =>
      'BloomOAuthUserProfile(provider: $provider, providerUserId: $providerUserId, email: $email, displayName: $displayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomOAuthUserProfile &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          providerUserId == other.providerUserId &&
          email == other.email &&
          displayName == other.displayName &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode =>
      Object.hash(provider, providerUserId, email, displayName, avatarUrl);
}

/// Abstract contract defining an OAuth2 Authorization Code flow provider in Bloom.
///
/// Implementations handle provider-specific endpoints, URL construction, authorization
/// code exchange, and user profile normalization for identity providers such as Google,
/// GitHub, and custom OpenID Connect (OIDC) servers.
abstract class BloomOAuthProvider {
  /// The canonical lowercase name of the OAuth provider (e.g. `'google'`, `'github'`).
  String get name;

  /// Constructs the authorization redirect URL sending the user to the provider's OAuth consent screen.
  ///
  /// [redirectUri] must match one of the authorized callback URLs registered with the provider.
  /// [state] is a cryptographically secure CSRF protection token (e.g. generated via `generateOAuthState`).
  /// [scopes] optionally overrides the provider's default requested scopes.
  Uri buildAuthorizationUrl({
    required String redirectUri,
    required String state,
    List<String>? scopes,
  });

  /// Exchanges an authorization [code] received at the callback endpoint for access and refresh tokens.
  ///
  /// [redirectUri] must match the exact `redirectUri` used during authorization URL construction.
  /// Throws [BloomOAuthException] if the exchange fails or is rejected by the provider.
  Future<BloomOAuthTokenResponse> exchangeCode({
    required String code,
    required String redirectUri,
  });

  /// Fetches and normalizes the authenticated user's profile using the provided [accessToken].
  ///
  /// Throws [BloomOAuthException] if the request is unauthorized or profile retrieval fails.
  Future<BloomOAuthUserProfile> fetchUserProfile(String accessToken);
}
