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
use std::path::PathBuf;
use std::time::Duration;

use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE};
use serde::{Deserialize, Serialize};

use crate::infra::executor::{redact, CommandExecutor, CommandSpec, ExecutorError};
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

/// Extended execution timeout for IPA binary uploads via Apple tooling (30 minutes / 1800 seconds).
///
/// Binary IPA payloads can exceed 100MB+ and require chunked validation by Apple's ingestion servers.
/// A 30-minute ceiling guarantees slow network uplinks complete without prematurely failing valid builds.
pub const IPA_UPLOAD_TIMEOUT: Duration = Duration::from_secs(30 * 60);

/// Environment variable name used to pass the App-Specific Password to `xcrun altool`.
///
/// Apple's `man altool` specifies `-p @env:<VAR_NAME>` to securely read credentials from the
/// environment rather than placing plaintext secrets on argv or in shell history.
pub const ALTOOL_PASSWORD_ENV_VAR: &str = "ALTOOL_PASSWORD";

/// Expected audience claim for App Store Connect API JWT tokens.
/// Authorised by EXTERNAL_APIS.txt line 163.
pub const APP_STORE_CONNECT_AUDIENCE: &str = "appstoreconnect-v1";

/// Target platform for Apple tooling binary uploads.
///
/// Authorised by `man altool` (`--type {macos | ios | appletvos | visionos}`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum TestFlightPlatform {
    /// iOS platform (`ios`).
    #[default]
    Ios,
    /// macOS platform (`macos`).
    Macos,
    /// Apple tvOS platform (`appletvos`).
    AppletvOs,
    /// Apple visionOS platform (`visionos`).
    VisionOs,
}

impl TestFlightPlatform {
    /// Returns the canonical CLI platform identifier string for `xcrun altool --type`.
    pub fn as_str(&self) -> &'static str {
        match self {
            TestFlightPlatform::Ios => "ios",
            TestFlightPlatform::Macos => "macos",
            TestFlightPlatform::AppletvOs => "appletvos",
            TestFlightPlatform::VisionOs => "visionos",
        }
    }

    /// Parses a platform string into a [`TestFlightPlatform`] variant.
    pub fn from_str_opt(s: &str) -> Option<Self> {
        match s.trim().to_ascii_lowercase().as_str() {
            "ios" => Some(TestFlightPlatform::Ios),
            "macos" => Some(TestFlightPlatform::Macos),
            "appletvos" | "tvos" => Some(TestFlightPlatform::AppletvOs),
            "visionos" => Some(TestFlightPlatform::VisionOs),
            _ => None,
        }
    }
}

impl fmt::Display for TestFlightPlatform {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Options for configuring an `xcrun altool` binary upload invocation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AltoolUploadOptions {
    /// Target platform type (defaults to [`TestFlightPlatform::Ios`]).
    pub platform: TestFlightPlatform,
    /// Custom working directory for the command.
    pub working_dir: Option<PathBuf>,
    /// Execution timeout for the upload operation.
    pub timeout: Duration,
}

impl Default for AltoolUploadOptions {
    fn default() -> Self {
        Self {
            platform: TestFlightPlatform::Ios,
            working_dir: None,
            timeout: IPA_UPLOAD_TIMEOUT,
        }
    }
}

/// Individual error entry returned in `xcrun altool` JSON output.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct AltoolProductError {
    /// Numeric or string error code from Apple (e.g. -1011, 90034, 1190).
    #[serde(default)]
    pub code: Option<serde_json::Value>,
    /// Human-readable error message.
    #[serde(default)]
    pub message: Option<String>,
    /// Additional context dictionary from Apple foundation tooling.
    #[serde(rename = "userInfo", default)]
    pub user_info: Option<serde_json::Value>,
}

impl AltoolProductError {
    /// Returns the string representation of the error code, if present.
    pub fn code_str(&self) -> Option<String> {
        match &self.code {
            Some(serde_json::Value::Number(n)) => Some(n.to_string()),
            Some(serde_json::Value::String(s)) => Some(s.clone()),
            _ => None,
        }
    }

    /// Returns the resolved error message combining the primary message and user info details.
    pub fn resolved_message(&self) -> String {
        if let Some(ref msg) = self.message {
            if !msg.trim().is_empty() {
                return msg.clone();
            }
        }
        if let Some(serde_json::Value::Object(map)) = &self.user_info {
            for key in [
                "NSLocalizedDescription",
                "NSLocalizedFailureReason",
                "description",
            ] {
                if let Some(serde_json::Value::String(val)) = map.get(key) {
                    if !val.trim().is_empty() {
                        return val.clone();
                    }
                }
            }
        }
        "Unknown Apple tooling error".to_string()
    }
}

/// Root JSON envelope emitted by `xcrun altool --output-format json`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct AltoolJsonResponse {
    /// Version of the altool utility.
    #[serde(rename = "tool-version", default)]
    pub tool_version: Option<String>,
    /// Operating system version.
    #[serde(rename = "os-version", default)]
    pub os_version: Option<String>,
    /// Array of product validation or upload errors.
    #[serde(rename = "product-errors", default)]
    pub product_errors: Option<Vec<AltoolProductError>>,
    /// Generic errors array fallback.
    #[serde(default)]
    pub errors: Option<Vec<AltoolProductError>>,
    /// Success confirmation message if present.
    #[serde(rename = "success-message", default)]
    pub success_message: Option<String>,
}

/// Errors arising from App Store Connect / TestFlight operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TestFlightError {
    /// Client or API credentials are not configured, or Apple tooling is not installed.
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
    /// Apple rejected the uploaded IPA binary (e.g. bad bundle ID, missing entitlement, invalid provisioning profile).
    BinaryRejected {
        /// Vendor error code if available (e.g. "ITMS-90034", "90189", "-1190").
        code: Option<String>,
        /// Descriptive message from Apple tooling or validation logs.
        message: String,
    },
    /// Transient network or timeout failure during upload (retryable).
    Transport {
        /// Details of the transport failure or timeout.
        message: String,
        /// Whether the failure is transient and retryable.
        retryable: bool,
    },
    /// Upload process or command execution failed with non-zero exit status and unparseable output.
    ExecutionFailed {
        /// Process exit code if available.
        exit_code: Option<i32>,
        /// Redacted standard error output.
        stderr: String,
    },
}

impl TestFlightError {
    /// Returns `true` if the error represents a transient network or timeout condition that can be retried.
    pub fn is_retryable(&self) -> bool {
        match self {
            TestFlightError::Transport { retryable, .. } => *retryable,
            TestFlightError::Http(_) => true,
            _ => false,
        }
    }
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
            TestFlightError::BinaryRejected { code, message } => match code {
                Some(c) => write!(f, "Apple binary rejected ({c}): {message}"),
                None => write!(f, "Apple binary rejected: {message}"),
            },
            TestFlightError::Transport { message, retryable } => {
                let r_str = if *retryable {
                    "retryable"
                } else {
                    "non-retryable"
                };
                write!(f, "TestFlight transport failure ({r_str}): {message}")
            }
            TestFlightError::ExecutionFailed { exit_code, stderr } => {
                let code_str = exit_code
                    .map(|c| c.to_string())
                    .unwrap_or_else(|| "signal".to_string());
                write!(
                    f,
                    "Apple tooling execution failed (exit code {code_str}): {stderr}"
                )
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

    /// Uploads an IPA binary payload via Apple's native command-line tooling (`xcrun altool --upload-app`).
    ///
    /// The app-specific password is provided to the child process exclusively through the
    /// environment (`@env:ALTOOL_PASSWORD`), ensuring credentials never appear on argv.
    ///
    /// # Parameters
    /// - `executor`: Sandboxed command executor seam ([`CommandExecutor`]).
    /// - `ipa_path`: Path to the `.ipa` or `.pkg` binary artifact on disk.
    /// - `apple_id`: Apple ID username (email address).
    /// - `app_specific_password`: Dedicated App-Specific Password for App Store Connect.
    pub async fn upload_ipa_tooling(
        &self,
        executor: &dyn CommandExecutor,
        ipa_path: &str,
        apple_id: &str,
        app_specific_password: &str,
    ) -> Result<(), TestFlightError> {
        self.upload_ipa_tooling_with_options(
            executor,
            ipa_path,
            apple_id,
            app_specific_password,
            &AltoolUploadOptions::default(),
        )
        .await
    }

    /// Uploads an IPA binary payload with customized platform and timeout options.
    ///
    /// # Parameters
    /// - `executor`: Sandboxed command executor seam ([`CommandExecutor`]).
    /// - `ipa_path`: Path to the `.ipa` or `.pkg` binary artifact on disk.
    /// - `apple_id`: Apple ID username (email address).
    /// - `app_specific_password`: Dedicated App-Specific Password for App Store Connect.
    /// - `options`: Upload parameters including target platform, working dir, and timeout.
    pub async fn upload_ipa_tooling_with_options(
        &self,
        executor: &dyn CommandExecutor,
        ipa_path: &str,
        apple_id: &str,
        app_specific_password: &str,
        options: &AltoolUploadOptions,
    ) -> Result<(), TestFlightError> {
        let trimmed_path = ipa_path.trim();
        if trimmed_path.is_empty() {
            return Err(TestFlightError::BinaryRejected {
                code: None,
                message: "IPA binary file path cannot be empty".to_string(),
            });
        }

        let trimmed_id = apple_id.trim();
        if trimmed_id.is_empty() {
            return Err(TestFlightError::Auth(
                "Apple ID username cannot be empty".to_string(),
            ));
        }

        let trimmed_pwd = app_specific_password.trim();
        if trimmed_pwd.is_empty() {
            return Err(TestFlightError::Auth(
                "App-specific password cannot be empty".to_string(),
            ));
        }

        let working_dir = options
            .working_dir
            .clone()
            .unwrap_or_else(|| PathBuf::from("."));

        let args = build_altool_upload_args(
            trimmed_path,
            options.platform,
            trimmed_id,
            ALTOOL_PASSWORD_ENV_VAR,
        );

        let spec = CommandSpec::new("xcrun", working_dir)
            .with_args(args)
            .with_env_var(ALTOOL_PASSWORD_ENV_VAR, trimmed_pwd)
            .with_timeout(options.timeout);

        let output_res = executor.run(&spec).await;

        match output_res {
            Ok(output) => {
                let clean_stdout = redact(&output.stdout, &[trimmed_pwd]);
                let clean_stderr = redact(&output.stderr, &[trimmed_pwd]);

                if let Some(errors) = parse_altool_errors_from_output(&clean_stdout, &clean_stderr)
                {
                    if let Some(first_err) = errors.first() {
                        return Err(classify_altool_error(first_err));
                    }
                }

                // LocalExecutor converts a non-zero exit into ExecutorError::NonZeroExit, so an
                // Ok here normally implies success. That is the executor's behaviour, not a
                // guarantee of the CommandExecutor trait, and reporting a successful upload is
                // exactly the claim that must never be fabricated -- so verify it explicitly
                // rather than inferring it from the absence of a parsed error.
                if !output.is_success() {
                    return Err(TestFlightError::ExecutionFailed {
                        exit_code: output.exit_code,
                        stderr: clean_stderr,
                    });
                }

                Ok(())
            }
            Err(ExecutorError::Spawn(e)) => Err(TestFlightError::NotConfigured(format!(
                "Apple tooling (xcrun/altool) is not available: {e}"
            ))),
            Err(ExecutorError::Timeout { seconds }) => Err(TestFlightError::Transport {
                message: format!("IPA binary upload timed out after {seconds} seconds"),
                retryable: true,
            }),
            Err(ExecutorError::Io(e)) => Err(TestFlightError::Transport {
                message: format!("I/O error executing Apple upload tooling: {e}"),
                retryable: true,
            }),
            Err(ExecutorError::NonZeroExit { code, stderr }) => {
                let clean_stderr = redact(&stderr, &[trimmed_pwd]);

                if let Some(errors) = parse_altool_errors_from_output("", &clean_stderr) {
                    if let Some(first_err) = errors.first() {
                        return Err(classify_altool_error(first_err));
                    }
                }

                let stderr_lower = clean_stderr.to_ascii_lowercase();

                // Check for missing xcrun / altool tooling
                if clean_stderr.contains("xcrun: error:")
                    || clean_stderr.contains("unable to find utility")
                    || stderr_lower.contains("command not found")
                    || stderr_lower.contains("no such file or directory")
                {
                    return Err(TestFlightError::NotConfigured(clean_stderr));
                }

                // Check for auth rejection in raw text
                if stderr_lower.contains("authenticate")
                    || stderr_lower.contains("authentication")
                    || stderr_lower.contains("credentials")
                    || stderr_lower.contains("unauthorized")
                    || stderr_lower.contains("password")
                {
                    return Err(TestFlightError::Auth(clean_stderr));
                }

                // Check for transport / network errors in raw text
                if stderr_lower.contains("timed out")
                    || stderr_lower.contains("timeout")
                    || stderr_lower.contains("connection reset")
                    || stderr_lower.contains("connection refused")
                    || stderr_lower.contains("network")
                {
                    return Err(TestFlightError::Transport {
                        message: clean_stderr,
                        retryable: true,
                    });
                }

                Err(TestFlightError::ExecutionFailed {
                    exit_code: code,
                    stderr: clean_stderr,
                })
            }
        }
    }
}

/// Constructs the pure, unit-testable argv list for `xcrun altool --upload-app`.
///
/// Passes arguments directly without shell interpretation to avoid command injection.
/// The password secret is referenced via the `@env:<VAR_NAME>` syntax and never placed on argv.
/// Authorised by `man altool` and EXTERNAL_APIS.txt lines 171-176.
pub fn build_altool_upload_args(
    ipa_path: &str,
    platform: TestFlightPlatform,
    apple_id: &str,
    env_password_var: &str,
) -> Vec<String> {
    vec![
        "altool".to_string(),
        "--upload-app".to_string(),
        "-f".to_string(),
        ipa_path.to_string(),
        "-t".to_string(),
        platform.as_str().to_string(),
        "-u".to_string(),
        apple_id.to_string(),
        "-p".to_string(),
        format!("@env:{env_password_var}"),
        "--output-format".to_string(),
        "json".to_string(),
    ]
}

/// Extracts structured JSON substring from raw CLI output if present.
pub fn extract_json_from_output(output: &str) -> Option<&str> {
    let start = output.find('{')?;
    let end = output.rfind('}')?;
    if start <= end {
        Some(&output[start..=end])
    } else {
        None
    }
}

/// Parses `altool` JSON output and extracts errors if present.
pub fn parse_altool_errors_from_output(
    stdout: &str,
    stderr: &str,
) -> Option<Vec<AltoolProductError>> {
    for stream in [stdout, stderr] {
        if let Some(json_str) = extract_json_from_output(stream) {
            if let Ok(parsed) = serde_json::from_str::<AltoolJsonResponse>(json_str) {
                if let Some(errors) = parsed.product_errors {
                    if !errors.is_empty() {
                        return Some(errors);
                    }
                }
                if let Some(errors) = parsed.errors {
                    if !errors.is_empty() {
                        return Some(errors);
                    }
                }
            }
        }
    }
    None
}

/// Classifies an [`AltoolProductError`] into a strongly-typed [`TestFlightError`].
pub fn classify_altool_error(error: &AltoolProductError) -> TestFlightError {
    let code_str = error.code_str();
    let msg = error.resolved_message();
    let msg_lower = msg.to_ascii_lowercase();

    // 1. Authentication errors.
    //
    // -1011 is the documented "failed to authenticate for session" code and is confirmed against
    // Apple Developer Forums threads 706894 and 722946. The remaining classification is by
    // message text, which is what actually carries the signal here: Apple's auth failures are
    // reported under several codes (-24169, -18000, -22014 all appear in the wild) and no
    // published exhaustive list exists, so matching text is more reliable than guessing codes.
    let is_auth_code = matches!(code_str.as_deref(), Some("-1011") | Some("401"));
    let is_auth_text = msg_lower.contains("authenticate")
        || msg_lower.contains("authentication")
        || msg_lower.contains("invalid username or password")
        || msg_lower.contains("credentials")
        || msg_lower.contains("unauthorized")
        || msg_lower.contains("password");

    if is_auth_code || is_auth_text {
        return TestFlightError::Auth(msg);
    }

    // 2. Transient transport / timeout errors.
    //
    // Only HTTP-derived status codes are matched numerically. A previous revision also listed
    // 1519 as a transient Apple code; that value could not be substantiated against any primary
    // source and has been removed rather than left in as a guess. Retry classification here is
    // driven by message text, and a misclassification is safe in the conservative direction:
    // an unmatched error falls through to BinaryRejected, which is not retried.
    let is_transient_code = matches!(
        code_str.as_deref(),
        Some("500") | Some("502") | Some("503") | Some("504")
    );
    let is_transient_text = msg_lower.contains("timed out")
        || msg_lower.contains("timeout")
        || msg_lower.contains("connection reset")
        || msg_lower.contains("connection refused")
        || msg_lower.contains("network")
        || msg_lower.contains("temporarily unavailable")
        || msg_lower.contains("try again");

    if is_transient_code || is_transient_text {
        return TestFlightError::Transport {
            message: msg,
            retryable: true,
        };
    }

    // 3. Apple rejected binary (bad bundle ID, missing entitlement, invalid provisioning profile, SDK version, etc.)
    TestFlightError::BinaryRejected {
        code: code_str,
        message: msg,
    }
}
