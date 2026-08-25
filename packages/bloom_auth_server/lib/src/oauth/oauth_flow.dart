// lib/src/oauth/oauth_flow.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../session_token.dart';
import 'oauth_provider.dart';

/// Generates a cryptographically secure, URL-safe random string for OAuth2 state parameters.
///
/// Uses [Random.secure] to produce [bytesCount] bytes of cryptographically strong entropy
/// (defaults to 32 bytes / 256 bits), encoded in URL-safe unpadded Base64.
///
/// Protects against Cross-Site Request Forgery (CSRF) in OAuth authorization code flows.
///
/// Example:
/// ```dart
/// final state = generateOAuthState();
/// // Save state in HTTP-only secure cookie or Redis cache before redirecting...
/// final authUrl = provider.buildAuthorizationUrl(redirectUri: callbackUrl, state: state);
/// ```
String generateOAuthState({int bytesCount = 32}) {
  if (bytesCount < 16) {
    throw ArgumentError.value(
      bytesCount,
      'bytesCount',
      'OAuth state entropy must be at least 16 bytes',
    );
  }
  final random = Random.secure();
  final bytes = List<int>.generate(bytesCount, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Result of a completed OAuth authorization code flow.
///
/// Contains the retrieved [profile], the OAuth provider's [tokenResponse], the resolved
/// [claims], and the signed JWT [sessionToken] issued by Bloom.
///
/// Example:
/// ```dart
/// final result = await oauthFlow.handleCallback(
///   code: code,
///   redirectUri: redirectUri,
///   resolveUser: (profile) async => myUserResolver(profile),
/// );
/// print('Session token: ${result.sessionToken}');
/// print('User claims: ${result.claims.userId}');
/// ```
class BloomOAuthResult {
  /// The normalized user profile returned by the OAuth identity provider.
  final BloomOAuthUserProfile profile;

  /// The OAuth token response containing the provider's access and refresh tokens.
  final BloomOAuthTokenResponse tokenResponse;

  /// The verified session claims for the authenticated user.
  final BloomAuthClaims claims;

  /// The signed HMAC-SHA256 JWT session token issued for downstream client requests.
  final String sessionToken;

  /// Creates a [BloomOAuthResult] instance.
  const BloomOAuthResult({
    required this.profile,
    required this.tokenResponse,
    required this.claims,
    required this.sessionToken,
  });

  /// Converts the OAuth result into a JSON-serializable map.
  Map<String, dynamic> toMap() => {
        'token': sessionToken,
        'claims': claims.toMap(),
        'profile': profile.toMap(),
      };

  @override
  String toString() =>
      'BloomOAuthResult(provider: ${profile.provider}, userId: ${claims.userId}, email: ${claims.email})';
}

/// Orchestrator for executing OAuth2 authorization code flows with unified Bloom session token issuance.
///
/// Coordinates authorization URL generation, code-for-token exchange, profile fetching,
/// and issuing standard Bloom JWT session tokens via [issueSessionToken].
///
/// Because Bloom applications may manage users differently (e.g. `bloom_db`, PostgreSQL,
/// SQLite, or third-party databases), the `resolveUser` callback is injected by the caller,
/// allowing complete freedom to look up or create local user records before signing session tokens.
///
/// Example:
/// ```dart
/// final googleFlow = BloomOAuthFlow(
///   GoogleOAuthProvider(
///     clientId: BloomEnv.get('GOOGLE_CLIENT_ID'),
///     clientSecret: BloomEnv.get('GOOGLE_CLIENT_SECRET'),
///   ),
/// );
///
/// // 1. Start OAuth login: redirect user to provider consent screen
/// router.get('/auth/google/start', (req) async {
///   final state = generateOAuthState();
///   // Store state in session / secure cookie...
///   final authUrl = googleFlow.buildAuthorizationUrl(
///     redirectUri: 'https://api.example.com/auth/google/callback',
///     state: state,
///   );
///   return BloomResponse.redirect(authUrl.toString());
/// });
///
/// // 2. Handle callback: exchange code, resolve local user, and issue JWT session token
/// router.get('/auth/google/callback', (req) async {
///   final code = req.queryParams['code'];
///   if (code == null) return BloomResponse.badRequest('Missing code parameter');
///
///   final result = await googleFlow.handleCallback(
///     code: code,
///     redirectUri: 'https://api.example.com/auth/google/callback',
///     resolveUser: (profile) async {
///       // Look up or create local user record in database
///       final user = await db.findOrCreateUserByOAuth(
///         provider: profile.provider,
///         providerUserId: profile.providerUserId,
///         email: profile.email,
///         name: profile.displayName,
///       );
///
///       return BloomAuthClaims(
///         userId: user.id,
///         email: user.email,
///         roles: user.roles,
///         issuedAt: DateTime.now().toUtc(),
///         expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
///       );
///     },
///   );
///
///   return BloomResponse.json({
///     'token': result.sessionToken,
///     'user': result.claims.toMap(),
///   });
/// });
/// ```
class BloomOAuthFlow {
  /// The OAuth provider used by this flow instance.
  final BloomOAuthProvider provider;

  /// Creates a [BloomOAuthFlow] for the specified [provider].
  const BloomOAuthFlow(this.provider);

  /// Builds the authorization redirect URL with [redirectUri], [state], and optional [scopes].
  Uri buildAuthorizationUrl({
    required String redirectUri,
    required String state,
    List<String>? scopes,
  }) {
    return provider.buildAuthorizationUrl(
      redirectUri: redirectUri,
      state: state,
      scopes: scopes,
    );
  }

  /// Exchanges the authorization [code] and fetches the authenticated [BloomOAuthUserProfile].
  ///
  /// Useful when you want to handle user resolution and token issuance manually.
  Future<({BloomOAuthTokenResponse tokenResponse, BloomOAuthUserProfile profile})>
      exchangeAndFetchProfile({
    required String code,
    required String redirectUri,
  }) async {
    final tokenResponse = await provider.exchangeCode(
      code: code,
      redirectUri: redirectUri,
    );
    final profile = await provider.fetchUserProfile(tokenResponse.accessToken);
    return (tokenResponse: tokenResponse, profile: profile);
  }

  /// Handles the complete OAuth callback lifecycle:
  /// 1. Exchanges [code] for access token via [provider.exchangeCode].
  /// 2. Fetches user profile via [provider.fetchUserProfile].
  /// 3. Resolves local user claims via [resolveUser].
  /// 4. Issues signed JWT bearer session token via [issueSessionToken].
  ///
  /// [sessionTtl] specifies session token validity duration (defaults to 7 days).
  /// [secret] is the optional HMAC signing secret override.
  /// [issuer] is the JWT issuer claim (defaults to `'bloom-auth-server'`).
  ///
  /// Returns a [BloomOAuthResult] containing the profile, token response, claims, and session token.
  Future<BloomOAuthResult> handleCallback({
    required String code,
    required String redirectUri,
    required FutureOr<BloomAuthClaims> Function(BloomOAuthUserProfile profile) resolveUser,
    Duration sessionTtl = const Duration(days: 7),
    String? issuer = 'bloom-auth-server',
    String? secret,
  }) async {
    final exchange = await exchangeAndFetchProfile(
      code: code,
      redirectUri: redirectUri,
    );

    final claims = await resolveUser(exchange.profile);

    final sessionToken = issueSessionToken(
      userId: claims.userId,
      email: claims.email,
      roles: claims.roles,
      customClaims: claims.customClaims,
      ttl: sessionTtl,
      issuer: issuer,
      secret: secret,
    );

    return BloomOAuthResult(
      profile: exchange.profile,
      tokenResponse: exchange.tokenResponse,
      claims: claims,
      sessionToken: sessionToken,
    );
  }
}
