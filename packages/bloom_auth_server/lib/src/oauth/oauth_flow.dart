// lib/src/oauth/oauth_flow.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../session_token.dart';
import 'oauth_provider.dart';

/// Exception thrown when OAuth state parameter verification fails.
class BloomOAuthStateException implements Exception {
  /// Description of the state verification failure.
  final String message;

  /// Creates a [BloomOAuthStateException] with the given [message].
  const BloomOAuthStateException(this.message);

  @override
  String toString() => 'BloomOAuthStateException: $message';
}

/// Interface for storing and verifying OAuth state tokens to prevent CSRF attacks.
///
/// Implementations must store issued state tokens and consume them atomically
/// upon callback validation, ensuring each state token is single-use.
abstract interface class BloomOAuthStateStore {
  /// Saves a newly generated [state] token with an expiration [ttl].
  FutureOr<void> save(String state,
      {Duration ttl = const Duration(minutes: 10)});

  /// Validates that [state] is known and unexpired, then immediately consumes (removes) it.
  ///
  /// Returns `true` if the state token was valid and successfully consumed, `false` otherwise.
  FutureOr<bool> validateAndConsume(String state);
}

/// In-memory [BloomOAuthStateStore] implementation with automatic expiration and single-use consumption.
class InMemoryOAuthStateStore implements BloomOAuthStateStore {
  final Map<String, DateTime> _states = {};

  @override
  FutureOr<void> save(String state,
      {Duration ttl = const Duration(minutes: 10)}) {
    _prune();
    _states[state] = DateTime.now().toUtc().add(ttl);
  }

  @override
  FutureOr<bool> validateAndConsume(String state) {
    _prune();
    final expiresAt = _states.remove(state);
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isBefore(expiresAt);
  }

  void _prune() {
    final now = DateTime.now().toUtc();
    _states.removeWhere((_, expiresAt) => now.isAfter(expiresAt));
  }

  /// Number of active state tokens stored.
  int get count {
    _prune();
    return _states.length;
  }
}

/// Generates a cryptographically secure, URL-safe random string for OAuth2 state parameters.
///
/// Uses [Random.secure] to produce [bytesCount] bytes of cryptographically strong entropy
/// (defaults to 32 bytes / 256 bits), encoded in URL-safe unpadded Base64.
///
/// **Security Note**: Generating a random state string only helps defend against Cross-Site
/// Request Forgery (CSRF) if the server records the state (e.g. via [BloomOAuthStateStore])
/// and validates/consumes it when the identity provider redirects to the callback endpoint.
///
/// Example:
/// ```dart
/// final stateStore = InMemoryOAuthStateStore();
/// final state = generateOAuthState();
/// await stateStore.save(state);
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
/// Coordinates authorization URL generation, state generation/storage, code-for-token exchange,
/// profile fetching, state verification, and issuing standard Bloom JWT session tokens via [issueSessionToken].
///
/// Because Bloom applications may manage users differently (e.g. `bloom_db`, PostgreSQL,
/// SQLite, or third-party databases), the `resolveUser` callback is injected by the caller,
/// allowing complete freedom to look up or create local user records before signing session tokens.
///
/// Example:
/// ```dart
/// final stateStore = InMemoryOAuthStateStore();
/// final googleFlow = BloomOAuthFlow(
///   GoogleOAuthProvider(
///     clientId: BloomEnv.get('GOOGLE_CLIENT_ID'),
///     clientSecret: BloomEnv.get('GOOGLE_CLIENT_SECRET'),
///   ),
///   stateStore: stateStore,
/// );
///
/// // 1. Start OAuth login: generate state and redirect user to provider consent screen
/// router.get('/auth/google/start', (req) async {
///   final state = await googleFlow.generateAndSaveState();
///   final authUrl = googleFlow.buildAuthorizationUrl(
///     redirectUri: 'https://api.example.com/auth/google/callback',
///     state: state,
///   );
///   return BloomResponse.redirect(authUrl.toString());
/// });
///
/// // 2. Handle callback: verify state token, exchange code, resolve local user, and issue JWT session token
/// router.get('/auth/google/callback', (req) async {
///   final code = req.queryParams['code'];
///   final state = req.queryParams['state'];
///   if (code == null) return BloomResponse.badRequest('Missing code parameter');
///
///   final result = await googleFlow.handleCallback(
///     code: code,
///     redirectUri: 'https://api.example.com/auth/google/callback',
///     state: state,
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

  /// Optional state store for managing and verifying CSRF state tokens.
  final BloomOAuthStateStore? stateStore;

  /// Creates a [BloomOAuthFlow] for the specified [provider] and optional [stateStore].
  const BloomOAuthFlow(this.provider, {this.stateStore});

  /// Generates a cryptographically secure state token, saves it to [stateStore] if configured,
  /// and returns the state string.
  ///
  /// [ttl] defines the state validity lifetime (defaults to 10 minutes).
  Future<String> generateAndSaveState({
    int bytesCount = 32,
    Duration ttl = const Duration(minutes: 10),
  }) async {
    final state = generateOAuthState(bytesCount: bytesCount);
    if (stateStore != null) {
      await stateStore!.save(state, ttl: ttl);
    }
    return state;
  }

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
  Future<
      ({
        BloomOAuthTokenResponse tokenResponse,
        BloomOAuthUserProfile profile
      })> exchangeAndFetchProfile({
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
  /// 1. Verifies and consumes [state] via [stateStore] (if [stateStore] is configured or [requireStateVerification] is true).
  /// 2. Exchanges [code] for access token via [provider.exchangeCode].
  /// 3. Fetches user profile via [provider.fetchUserProfile].
  /// 4. Resolves local user claims via [resolveUser].
  /// 5. Issues signed JWT bearer session token via [issueSessionToken].
  ///
  /// [sessionTtl] specifies session token validity duration (defaults to 7 days).
  /// [secret] is the optional HMAC signing secret override.
  /// [issuer] is the JWT issuer claim (defaults to `'bloom-auth-server'`).
  ///
  /// Throws [BloomOAuthStateException] if state verification is required/configured but missing, invalid, or expired.
  /// Returns a [BloomOAuthResult] containing the profile, token response, claims, and session token.
  Future<BloomOAuthResult> handleCallback({
    required String code,
    required String redirectUri,
    required FutureOr<BloomAuthClaims> Function(BloomOAuthUserProfile profile)
        resolveUser,
    String? state,
    bool requireStateVerification = false,
    Duration sessionTtl = const Duration(days: 7),
    String? issuer = 'bloom-auth-server',
    String? secret,
  }) async {
    if (stateStore != null || requireStateVerification) {
      if (state == null || state.isEmpty) {
        throw const BloomOAuthStateException(
          'Missing OAuth "state" parameter for verification',
        );
      }
      if (stateStore == null) {
        throw const BloomOAuthStateException(
          'OAuth state verification was required, but no BloomOAuthStateStore is configured',
        );
      }
      final isValid = await stateStore!.validateAndConsume(state);
      if (!isValid) {
        throw const BloomOAuthStateException(
          'Invalid or expired OAuth state token (CSRF verification failed)',
        );
      }
    }

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
