//! App Store Connect API / TestFlight infrastructure client.
//!
//! # Architecture & Scope
//!
//! Provides automated iOS beta deployment and build management capabilities via the
//! Apple App Store Connect REST API v1.
//!
//! # Authentication & JWT Lifecycle (Strict Rules)
//!
//! - **Algorithm**: ES256 (ECDSA using P-256 and SHA-256) signed with the `.p8` private key.
//! - **Header**: `{ "alg": "ES256", "kid": "<Key ID, 10 chars>", "typ": "JWT" }`
//! - **Payload**: `{ "iss": "<Issuer ID, a UUID>", "iat": <unix now>, "exp": <unix now + lifetime>, "aud": "appstoreconnect-v1" }`
//! - **Strict 20-Minute Expiry Limit**: Apple enforces a hard maximum lifetime of **20 minutes (1200 seconds)**.
//!   Any JWT whose `exp` is more than 20 minutes in the future is rejected with HTTP `401 Unauthorized`.
//!   Bloom Cloud enforces a default lifetime of **15 minutes (900 seconds)** ([`DEFAULT_JWT_LIFETIME_SECS`])
//!   and rejects any duration > 1200 seconds ([`MAX_JWT_LIFETIME_SECS`]).
//! - **Single-Run Minting**: Mint a fresh token per deployment run; never cache tokens across long uploads.
//!
//! # Binary Upload Architecture
//!
//! **THERE IS NO REST ENDPOINT THAT UPLOADS AN IPA.**
//!
//! Apple accepts binary payloads (`.ipa`) exclusively via Apple's native command-line tooling:
//! `xcrun altool --upload-app` or Transporter (`iTMSTransporter`). The App Store Connect REST API
//! is used exclusively for querying build processing states and assigning builds to beta groups
//! after the binary has been uploaded by the tooling.
//!
//! # Processing State Invariants
//!
//! Build processing state values (`processingState`) are confirmed from Fastlane's spaceship `ProcessingState` module:
//! - `PROCESSING`: still in progress
//! - `VALID`: terminal success; the build is usable
//! - `FAILED`: terminal failure
//! - `INVALID`: terminal failure
//!
//! Unrecognised values are defensively mapped to [`TestFlightProcessingState::Unknown`] / still processing,
//! rather than treating unrecognized values as terminal failure.
//!
//! # Secret Hygiene
//!
//! Private keys (`.p8`), bearer tokens, and credentials MUST NEVER be logged. [`TestFlightConfig`]
//! implements custom `Debug` redaction.

use std::fmt;
use std::time::Duration;

use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE};
use serde::{Deserialize, Serialize};

use crate::settings::TestFlightSettings;

/// Default base URL for App Store Connect API v1.
/// Authorised by EXTERNAL_APIS.txt line 157.
pub const DEFAULT_APP_STORE_CONNECT_BASE_URL: &str = "https://api.appstoreconnect.apple.com";

/// Hard maximum JWT lifetime allowed by Apple (20 minutes / 1200 seconds).
/// Any token with exp > 1200s from iat is rejected with HTTP 401.
/// Authorised by EXTERNAL_APIS.txt lines 164-166.
pub const MAX_JWT_LIFETIME_SECS: u64 = 1200;

/// Default JWT token lifetime used by Bloom Cloud (15 minutes / 900 seconds).
/// Set safely below the 20-minute hard ceiling to tolerate clock drift.
/// Authorised by EXTERNAL_APIS.txt lines 164-166.
pub const DEFAULT_JWT_LIFETIME_SECS: u64 = 900;

/// Standard HTTP request timeout for App Store Connect API calls (30 seconds).
pub const DEFAULT_TESTFLIGHT_TIMEOUT: Duration = Duration::from_secs(30);

/// Expected audience claim for App Store Connect API JWT tokens.
/// Authorised by EXTERNAL_APIS.txt line 163.
pub const APP_STORE_CONNECT_AUDIENCE: &str = "appstoreconnect-v1";

/// Errors arising from App Store Connect / TestFlight operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TestFlightError {
    /// Client or API credentials are not configured.
    NotConfigured(String),
    /// Request payload serialization or response parsing failure.
    Serialization(String),
    /// Network transport or HTTP protocol failure.
    Http(String),
    /// Authentication or JWT signing error.
    Auth(String),
    /// JWT expiration duration exceeds Apple's 20-minute ceiling.
    InvalidLifetime(String),
    /// App Store Connect API returned a non-success HTTP status code.
    Api {
        /// HTTP status code returned by App Store Connect.
        status: u16,
        /// Error message or body from the API.
        message: String,
    },
}

impl fmt::Display for TestFlightError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            TestFlightError::NotConfigured(msg) => {
                write!(f, "TestFlight client not configured: {msg}")
            }
            TestFlightError::Serialization(msg) => {
                write!(f, "TestFlight serialization error: {msg}")
            }
            TestFlightError::Http(msg) => write!(f, "TestFlight HTTP transport error: {msg}"),
            TestFlightError::Auth(msg) => write!(f, "TestFlight authentication error: {msg}"),
            TestFlightError::InvalidLifetime(msg) => {
                write!(f, "TestFlight invalid JWT lifetime: {msg}")
            }
            TestFlightError::Api { status, message } => {
                write!(f, "App Store Connect API error (HTTP {status}): {message}")
            }
        }
    }
}

impl std::error::Error for TestFlightError {}

/// JWT Header object for App Store Connect API authentication.
///
/// Authorised by EXTERNAL_APIS.txt line 161: `{ "alg": "ES256", "kid": "<Key ID>", "typ": "JWT" }`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppStoreJwtHeader {
    /// Algorithm identifier, strictly "ES256".
    pub alg: String,
    /// 10-character Key ID from App Store Connect.
    pub kid: String,
    /// Type discriminator, strictly "JWT".
    pub typ: String,
}

impl AppStoreJwtHeader {
    /// Creates a new `AppStoreJwtHeader` for the given Key ID.
    pub fn new(key_id: impl Into<String>) -> Self {
        Self {
            alg: "ES256".to_string(),
            kid: key_id.into(),
            typ: "JWT".to_string(),
        }
    }
}

/// JWT Claims payload object for App Store Connect API authentication.
///
/// Authorised by EXTERNAL_APIS.txt lines 162-163.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppStoreJwtClaims {
    /// Issuer ID (UUID string from App Store Connect).
    pub iss: String,
    /// Issued-at timestamp in epoch seconds.
    pub iat: i64,
    /// Expiration timestamp in epoch seconds (strictly <= 20 minutes from `iat`).
    pub exp: i64,
    /// Audience claim, strictly `"appstoreconnect-v1"`.
    pub aud: String,
}

impl AppStoreJwtClaims {
    /// Constructs claims with explicit issued-at and expiration timestamps.
    ///
    /// Fails if `exp - iat > MAX_JWT_LIFETIME_SECS` (1200 seconds / 20 minutes).
    pub fn new(issuer_id: impl Into<String>, iat: i64, exp: i64) -> Result<Self, TestFlightError> {
        let lifetime = exp.saturating_sub(iat);
        if lifetime > MAX_JWT_LIFETIME_SECS as i64 {
            return Err(TestFlightError::InvalidLifetime(format!(
                "JWT lifetime of {lifetime}s exceeds Apple maximum of {MAX_JWT_LIFETIME_SECS}s (20 minutes)"
            )));
        }
        if lifetime <= 0 {
            return Err(TestFlightError::InvalidLifetime(format!(
                "JWT expiration ({exp}) must be greater than issued-at ({iat})"
            )));
        }

        Ok(Self {
            iss: issuer_id.into(),
            iat,
            exp,
            aud: APP_STORE_CONNECT_AUDIENCE.to_string(),
        })
    }

    /// Constructs claims for the current time with the default lifetime ([`DEFAULT_JWT_LIFETIME_SECS`]).
    pub fn for_current_time(
        issuer_id: impl Into<String>,
        now_unix_secs: i64,
    ) -> Result<Self, TestFlightError> {
        let exp = now_unix_secs + DEFAULT_JWT_LIFETIME_SECS as i64;
        Self::new(issuer_id, now_unix_secs, exp)
    }
}

/// Build processing lifecycle state in TestFlight / App Store Connect.
///
/// Variants correspond to confirmed Fastlane spaceship `ProcessingState` values:
/// `PROCESSING`, `VALID`, `FAILED`, `INVALID`. Unrecognized values are defensively mapped to `Unknown`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TestFlightProcessingState {
    /// Build successfully finished processing and is ready for beta assignment (terminal success).
    Valid,
    /// Build is still being processed by Apple (in progress).
    Processing,
    /// Build processing failed with errors (terminal failure).
    Failed,
    /// Unrecognized status reported by Apple; defensively mapped to still processing.
    Unknown(String),
}

impl TestFlightProcessingState {
    /// Parses a raw `processingState` string from App Store Connect.
    ///
    /// Confirmed variants:
    /// - `"VALID"` -> [`TestFlightProcessingState::Valid`] (terminal success)
    /// - `"PROCESSING"` -> [`TestFlightProcessingState::Processing`] (in progress)
    /// - `"FAILED"` / `"INVALID"` -> [`TestFlightProcessingState::Failed`] (terminal failure)
    /// - Unrecognized values -> [`TestFlightProcessingState::Unknown`] (treated as in progress)
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 183-188 and Apple vendor tooling.
    pub fn from_raw(state: &str) -> Self {
        let trimmed = state.trim();
        if trimmed.eq_ignore_ascii_case("VALID") {
            TestFlightProcessingState::Valid
        } else if trimmed.eq_ignore_ascii_case("PROCESSING") {
            TestFlightProcessingState::Processing
        } else if trimmed.eq_ignore_ascii_case("FAILED") || trimmed.eq_ignore_ascii_case("INVALID")
        {
            TestFlightProcessingState::Failed
        } else {
            TestFlightProcessingState::Unknown(trimmed.to_string())
        }
    }

    /// Returns `true` if the build has finished processing successfully.
    pub fn is_ready(&self) -> bool {
        matches!(self, TestFlightProcessingState::Valid)
    }

    /// Returns `true` if the build is still processing or in an unknown provisional state.
    pub fn is_in_progress(&self) -> bool {
        matches!(
            self,
            TestFlightProcessingState::Processing | TestFlightProcessingState::Unknown(_)
        )
    }

    /// Returns `true` if the build processing has terminally failed.
    pub fn is_failed(&self) -> bool {
        matches!(self, TestFlightProcessingState::Failed)
    }
}

/// Attributes for an App Store Connect Build resource.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct AppStoreBuildAttributes {
    /// Bundle version string (CFBSnapshot / version number).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,
    /// Processing state string (e.g. "PROCESSING", "VALID", "INVALID", "FAILED").
    #[serde(rename = "processingState", skip_serializing_if = "Option::is_none")]
    pub processing_state: Option<String>,
    /// Upload timestamp ISO 8601 string.
    #[serde(rename = "uploadedDate", skip_serializing_if = "Option::is_none")]
    pub uploaded_date: Option<String>,
    /// Expiration date string.
    #[serde(rename = "expirationDate", skip_serializing_if = "Option::is_none")]
    pub expiration_date: Option<String>,
    /// Minimum OS version string.
    #[serde(rename = "minOsVersion", skip_serializing_if = "Option::is_none")]
    pub min_os_version: Option<String>,
}

/// JSON:API Resource object representing an App Store Connect Build.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppStoreBuildResource {
    /// Unique resource identifier for the build in App Store Connect.
    pub id: String,
    /// Resource type identifier, strictly `"builds"`.
    pub r#type: String,
    /// Build attributes.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub attributes: Option<AppStoreBuildAttributes>,
}

/// JSON:API response envelope containing a list of builds.
/// Authorised by EXTERNAL_APIS.txt line 181 (`GET /v1/builds`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppStoreBuildsResponse {
    /// Array of build resource objects.
    pub data: Vec<AppStoreBuildResource>,
}

/// JSON:API response envelope containing a single build.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppStoreSingleBuildResponse {
    /// Single build resource object.
    pub data: AppStoreBuildResource,
}

/// JSON:API resource linkage item for assigning a build to a beta group.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BetaGroupBuildLinkage {
    /// Identifier of the build resource.
    pub id: String,
    /// Resource type, strictly `"builds"`.
    pub r#type: String,
}

impl BetaGroupBuildLinkage {
    /// Creates a new build linkage for the given build ID.
    pub fn new(build_id: impl Into<String>) -> Self {
        Self {
            id: build_id.into(),
            r#type: "builds".to_string(),
        }
    }
}

/// Request payload for assigning builds to a beta group.
/// Authorised by EXTERNAL_APIS.txt line 182 (`POST /v1/betaGroups/{id}/builds`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BetaGroupBuildsRequest {
    /// List of build linkages to associate with the beta group.
    pub data: Vec<BetaGroupBuildLinkage>,
}

/// Configuration credentials for App Store Connect API.
#[derive(Clone, PartialEq, Eq)]
pub struct TestFlightConfig {
    /// API base URL.
    pub base_url: String,
    /// Issuer ID UUID string.
    pub issuer_id: Option<String>,
    /// 10-character Key ID string.
    pub key_id: Option<String>,
    /// Decrypted `.p8` private key PEM.
    pub private_key: Option<String>,
    /// Pre-minted Bearer JWT token if active.
    pub bearer_token: Option<String>,
}

// Redact private keys and bearer tokens in Debug representation
impl fmt::Debug for TestFlightConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("TestFlightConfig")
            .field("base_url", &self.base_url)
            .field("issuer_id", &self.issuer_id)
            .field("key_id", &self.key_id)
            .field(
                "private_key",
                &self.private_key.as_ref().map(|_| "[REDACTED]"),
            )
            .field(
                "bearer_token",
                &self.bearer_token.as_ref().map(|_| "[REDACTED]"),
            )
            .finish()
    }
}

/// App Store Connect API / TestFlight client.
#[derive(Clone)]
pub struct TestFlightClient {
    http: reqwest::Client,
    config: Option<TestFlightConfig>,
}

impl TestFlightClient {
    /// Creates a new `TestFlightClient` from typed settings and an optional pre-minted bearer token.
    pub fn new(settings: &TestFlightSettings, bearer_token: Option<String>) -> Self {
        let base_url = if settings.api_url.trim().is_empty() {
            DEFAULT_APP_STORE_CONNECT_BASE_URL.to_string()
        } else {
            settings.api_url.trim().trim_end_matches('/').to_string()
        };

        let token = bearer_token
            .map(|t| t.trim().to_string())
            .filter(|t| !t.is_empty());

        let config = if token.is_some() || settings.issuer_id.is_some() {
            Some(TestFlightConfig {
                base_url,
                issuer_id: settings.issuer_id.clone(),
                key_id: settings.key_id.clone(),
                private_key: settings.private_key.clone(),
                bearer_token: token,
            })
        } else {
            None
        };

        let http = reqwest::Client::builder()
            .timeout(DEFAULT_TESTFLIGHT_TIMEOUT)
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        Self { http, config }
    }

    /// Creates a `TestFlightClient` with an explicit base URL and pre-minted bearer JWT token.
    pub fn from_token(base_url: impl Into<String>, bearer_token: impl Into<String>) -> Self {
        let base_url = base_url.into().trim().trim_end_matches('/').to_string();
        let bearer_token = bearer_token.into().trim().to_string();

        let config = Some(TestFlightConfig {
            base_url: if base_url.is_empty() {
                DEFAULT_APP_STORE_CONNECT_BASE_URL.to_string()
            } else {
                base_url
            },
            issuer_id: None,
            key_id: None,
            private_key: None,
            bearer_token: Some(bearer_token),
        });

        let http = reqwest::Client::builder()
            .timeout(DEFAULT_TESTFLIGHT_TIMEOUT)
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        Self { http, config }
    }

    /// Creates an explicitly disabled / unconfigured `TestFlightClient`.
    pub fn unconfigured() -> Self {
        Self {
            http: reqwest::Client::new(),
            config: None,
        }
    }

    /// Returns `true` if the client has active credentials or a pre-minted bearer token.
    pub fn is_configured(&self) -> bool {
        self.config
            .as_ref()
            .map(|c| c.bearer_token.is_some() || (c.issuer_id.is_some() && c.key_id.is_some()))
            .unwrap_or(false)
    }

    // -------------------------------------------------------------------------
    // Endpoint URL Builders
    // -------------------------------------------------------------------------

    /// Constructs the query URL for filtering builds by App ID and Version string:
    /// `GET /v1/builds?filter[app]={app_id}&filter[version]={version}`
    /// Authorised by EXTERNAL_APIS.txt line 181.
    pub fn builds_query_url(base_url: &str, app_id: &str, version: &str) -> String {
        format!(
            "{}/v1/builds?filter[app]={}&filter[version]={}",
            base_url.trim_end_matches('/'),
            app_id.trim(),
            version.trim()
        )
    }

    /// Constructs the URL for fetching an individual build by ID:
    /// `GET /v1/builds/{build_id}`
    pub fn build_by_id_url(base_url: &str, build_id: &str) -> String {
        format!(
            "{}/v1/builds/{}",
            base_url.trim_end_matches('/'),
            build_id.trim()
        )
    }

    /// Constructs the URL for assigning a build to a beta group:
    /// `POST /v1/betaGroups/{beta_group_id}/builds`
    /// Authorised by EXTERNAL_APIS.txt line 182.
    pub fn beta_group_builds_url(base_url: &str, beta_group_id: &str) -> String {
        format!(
            "{}/v1/betaGroups/{}/builds",
            base_url.trim_end_matches('/'),
            beta_group_id.trim()
        )
    }

    // -------------------------------------------------------------------------
    // API Operations
    // -------------------------------------------------------------------------

    /// Builds authorization headers.
    fn build_headers(&self, config: &TestFlightConfig) -> Result<HeaderMap, TestFlightError> {
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));

        if let Some(token) = &config.bearer_token {
            let auth_val = format!("Bearer {token}");
            let mut auth_header = HeaderValue::from_str(&auth_val)
                .map_err(|e| TestFlightError::Serialization(format!("Invalid auth header: {e}")))?;
            auth_header.set_sensitive(true);
            headers.insert(AUTHORIZATION, auth_header);
        } else {
            return Err(TestFlightError::NotConfigured(
                "No active Bearer JWT token configured for App Store Connect client".to_string(),
            ));
        }

        Ok(headers)
    }

    /// Polls builds matching the given App ID and Version string.
    ///
    /// Returns the parsed [`TestFlightProcessingState`] of the newest build matching the filters.
    /// Authorised by EXTERNAL_APIS.txt line 181 (`GET /v1/builds?filter[app]={id}&filter[version]={v}`).
    pub async fn poll_build_processing_state(
        &self,
        app_id: &str,
        version: &str,
    ) -> Result<Option<TestFlightProcessingState>, TestFlightError> {
        let config = self.config.as_ref().ok_or_else(|| {
            TestFlightError::NotConfigured("TestFlight client is not configured".to_string())
        })?;

        let url = Self::builds_query_url(&config.base_url, app_id, version);
        let headers = self.build_headers(config)?;

        let response = self
            .http
            .get(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| TestFlightError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(TestFlightError::Api {
                status,
                message: body,
            });
        }

        let parsed: AppStoreBuildsResponse = response.json().await.map_err(|e| {
            TestFlightError::Serialization(format!("Failed parsing Builds response: {e}"))
        })?;

        let maybe_state = parsed
            .data
            .first()
            .and_then(|build| build.attributes.as_ref())
            .and_then(|attrs| attrs.processing_state.as_deref())
            .map(TestFlightProcessingState::from_raw);

        Ok(maybe_state)
    }

    /// Fetches an App Store Connect Build by its ID.
    pub async fn get_build(
        &self,
        build_id: &str,
    ) -> Result<AppStoreBuildResource, TestFlightError> {
        let config = self.config.as_ref().ok_or_else(|| {
            TestFlightError::NotConfigured("TestFlight client is not configured".to_string())
        })?;

        let url = Self::build_by_id_url(&config.base_url, build_id);
        let headers = self.build_headers(config)?;

        let response = self
            .http
            .get(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| TestFlightError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(TestFlightError::Api {
                status,
                message: body,
            });
        }

        let parsed: AppStoreSingleBuildResponse = response.json().await.map_err(|e| {
            TestFlightError::Serialization(format!("Failed parsing Build response: {e}"))
        })?;

        Ok(parsed.data)
    }

    /// Associates an uploaded build with a TestFlight Beta Group.
    ///
    /// Authorised by EXTERNAL_APIS.txt line 182 (`POST /v1/betaGroups/{id}/builds`).
    pub async fn assign_beta_group(
        &self,
        beta_group_id: &str,
        build_id: &str,
    ) -> Result<(), TestFlightError> {
        let config = self.config.as_ref().ok_or_else(|| {
            TestFlightError::NotConfigured("TestFlight client is not configured".to_string())
        })?;

        let url = Self::beta_group_builds_url(&config.base_url, beta_group_id);
        let headers = self.build_headers(config)?;

        let payload = BetaGroupBuildsRequest {
            data: vec![BetaGroupBuildLinkage::new(build_id)],
        };

        let response = self
            .http
            .post(&url)
            .headers(headers)
            .json(&payload)
            .send()
            .await
            .map_err(|e| TestFlightError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(TestFlightError::Api {
                status,
                message: body,
            });
        }

        Ok(())
    }

    /// Creates a signed ES256 JWT for App Store Connect API authentication.
    ///
    /// Headers: `{ "alg": "ES256", "kid": "<Key ID>", "typ": "JWT" }`
    /// Claims:
    /// - `iss`: `issuer_id` UUID
    /// - `iat`: `now_unix_secs`
    /// - `exp`: `now_unix_secs + 900` (default 15 minutes, strictly <= 1200 seconds)
    /// - `aud`: `"appstoreconnect-v1"`
    ///
    /// Key: PKCS#8 EC P-256 private key PEM (`.p8`).
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 160-166 and Apple App Store Connect API docs.
    pub fn create_signed_jwt(
        issuer_id: &str,
        key_id: &str,
        private_key_p8_pem: &str,
        now_unix_secs: i64,
    ) -> Result<String, TestFlightError> {
        if issuer_id.trim().is_empty() {
            return Err(TestFlightError::Auth(
                "App Store Connect issuer_id cannot be empty".to_string(),
            ));
        }
        if key_id.trim().is_empty() {
            return Err(TestFlightError::Auth(
                "App Store Connect key_id cannot be empty".to_string(),
            ));
        }
        if private_key_p8_pem.trim().is_empty() {
            return Err(TestFlightError::Auth(
                "App Store Connect private_key PEM cannot be empty".to_string(),
            ));
        }

        let claims = AppStoreJwtClaims::for_current_time(issuer_id.trim(), now_unix_secs)?;

        let mut header = jsonwebtoken::Header::new(jsonwebtoken::Algorithm::ES256);
        header.kid = Some(key_id.trim().to_string());
        header.typ = Some("JWT".to_string());

        let encoding_key = jsonwebtoken::EncodingKey::from_ec_pem(private_key_p8_pem.as_bytes())
            .map_err(|e| {
                TestFlightError::Auth(format!("Failed to parse EC private key PEM (.p8): {e}"))
            })?;

        jsonwebtoken::encode(&header, &claims, &encoding_key)
            .map_err(|e| TestFlightError::Auth(format!("Failed to sign ES256 JWT: {e}")))
    }

    /// Mints a signed ES256 JWT for App Store Connect API authentication.
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 160-166.
    pub fn mint_jwt_token(
        &self,
        issuer_id: &str,
        key_id: &str,
        private_key_p8_pem: &str,
        now_unix_secs: i64,
    ) -> Result<String, TestFlightError> {
        Self::create_signed_jwt(issuer_id, key_id, private_key_p8_pem, now_unix_secs)
    }

    /// Uploads an IPA binary payload via Apple's native command-line tooling.
    ///
    /// Note: Apple does not provide a REST endpoint for uploading binary IPAs.
    /// Authorised by EXTERNAL_APIS.txt lines 171-176.
    pub async fn upload_ipa_tooling(
        &self,
        _ipa_path: &str,
        _apple_id: &str,
        _app_specific_password: &str,
    ) -> Result<(), TestFlightError> {
        // TODO(spec): Apple accepts binary uploads only via xcrun altool --upload-app or iTMSTransporter; there is no REST upload endpoint.
        Err(TestFlightError::NotConfigured(
            "IPA binary upload requires local xcrun altool or iTMSTransporter tooling execution"
                .to_string(),
        ))
    }
}
