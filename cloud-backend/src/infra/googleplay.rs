//! Google Play Android Developer API v3 infrastructure client.
//!
//! # Architecture & Scope
//!
//! Provides automated Android app publishing capabilities to Google Play tracks via the
//! Google Play Android Developer API v3.
//!
//! Publishing follows the atomic Google Play **edit lifecycle**:
//! 1. **Create Edit** ([`create_edit`](GooglePlayClient::create_edit)): Initializes a new draft edit.
//! 2. **Upload Bundle** ([`upload_bundle`](GooglePlayClient::upload_bundle)): Streams Android App Bundle (`.aab`)
//!    bytes to the dedicated upload host.
//! 3. **Assign Track** ([`assign_track`](GooglePlayClient::assign_track)): Configures track release parameters,
//!    version codes, release notes, and rollout fractions.
//! 4. **Validate Edit** ([`validate_edit`](GooglePlayClient::validate_edit)): Validates the configured edit without committing.
//! 5. **Commit Edit** ([`commit_edit`](GooglePlayClient::commit_edit)): Atomically applies changes to production/internal tracks.
//! 6. **Poll Status** ([`get_track`](GooglePlayClient::get_track)): Inspects release status on the track.
//!
//! # Critical API Rules & Constraints
//!
//! - **Dedicated Upload Endpoint**: Bundle upload MUST use the `/upload/androidpublisher/v3/...` host path.
//!   The standard metadata endpoint will silently reject binary payload uploads.
//!   (Authorised by EXTERNAL_APIS.txt line 123).
//! - **Extended Upload Timeout**: Google explicitly mandates an HTTP timeout of **at least 2 minutes**
//!   for bundle upload calls ([`BUNDLE_UPLOAD_TIMEOUT`]).
//! - **Edit Expiry**: Google Play edits expire after an allocated duration (`expiryTimeSeconds`).
//!   Edits must be checked via [`AppEdit::is_expired`] prior to commitment to prevent stale commits.
//! - **Staged Rollouts (`userFraction`)**: `userFraction` must satisfy `0.0 < fraction < 1.0` and applies
//!   strictly to [`ReleaseStatus::InProgress`]. Submitting `userFraction = 1.0` or attaching a fraction
//!   to [`ReleaseStatus::Completed`] is rejected.
//! - **Secret Hygiene**: Service account credentials and OAuth tokens MUST NEVER be logged.
//!   [`GooglePlayConfig`] implements a custom `Debug` that redacts sensitive values.

use std::fmt;
use std::time::Duration;

use bytes::Bytes;
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE};
use serde::{Deserialize, Serialize};

use crate::settings::GooglePlaySettings;

/// Default base URL for Google Play Android Publisher API v3 metadata operations.
/// Authorised by EXTERNAL_APIS.txt line 112.
pub const DEFAULT_GOOGLE_PLAY_BASE_URL: &str = "https://androidpublisher.googleapis.com";

/// Required OAuth 2.0 scope for Android Publisher API operations.
/// Authorised by EXTERNAL_APIS.txt line 108.
pub const ANDROID_PUBLISHER_SCOPE: &str = "https://www.googleapis.com/auth/androidpublisher";

/// Extended HTTP request timeout for binary AAB bundle uploads (150 seconds / 2.5 minutes).
/// Google explicitly requires at least 2 minutes for binary uploads.
/// Authorised by EXTERNAL_APIS.txt lines 127-128.
pub const BUNDLE_UPLOAD_TIMEOUT: Duration = Duration::from_secs(150);

/// Standard HTTP request timeout for metadata and lifecycle operations (30 seconds).
pub const DEFAULT_GOOGLE_PLAY_TIMEOUT: Duration = Duration::from_secs(30);

/// Errors arising from Google Play Android Developer API operations.
#[derive(Debug, Clone, PartialEq)]
pub enum GooglePlayError {
    /// Client or API credentials are not configured.
    NotConfigured(String),
    /// Request payload serialization or response deserialization failure.
    Serialization(String),
    /// Network transport or HTTP protocol failure.
    Http(String),
    /// Authentication or OAuth 2.0 token minting error.
    Auth(String),
    /// Attempted to commit or operate on an edit that has expired.
    EditExpired {
        /// The identifier of the expired edit.
        edit_id: String,
        /// Expiry epoch timestamp reported by Google Play.
        expiry_time_secs: i64,
    },
    /// Invalid staged rollout `userFraction` configuration.
    InvalidUserFraction(String),
    /// Google Play API returned a non-success HTTP status code.
    Api {
        /// HTTP status code returned by Google Play.
        status: u16,
        /// Error message or body from the API.
        message: String,
    },
}

impl fmt::Display for GooglePlayError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            GooglePlayError::NotConfigured(msg) => {
                write!(f, "Google Play client not configured: {msg}")
            }
            GooglePlayError::Serialization(msg) => {
                write!(f, "Google Play serialization error: {msg}")
            }
            GooglePlayError::Http(msg) => write!(f, "Google Play HTTP transport error: {msg}"),
            GooglePlayError::Auth(msg) => write!(f, "Google Play authentication error: {msg}"),
            GooglePlayError::EditExpired {
                edit_id,
                expiry_time_secs,
            } => {
                write!(
                    f,
                    "Google Play edit '{edit_id}' expired at epoch second {expiry_time_secs}"
                )
            }
            GooglePlayError::InvalidUserFraction(msg) => {
                write!(f, "Google Play invalid userFraction: {msg}")
            }
            GooglePlayError::Api { status, message } => {
                write!(f, "Google Play API error (HTTP {status}): {message}")
            }
        }
    }
}

impl std::error::Error for GooglePlayError {}

/// Release status enum for a Google Play track release.
///
/// Must match Google Play's exact camelCase five-variant enum.
/// Authorised by EXTERNAL_APIS.txt lines 137-138.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ReleaseStatus {
    /// Unspecified status.
    #[serde(rename = "statusUnspecified")]
    StatusUnspecified,
    /// Draft release not yet rolled out.
    #[serde(rename = "draft")]
    Draft,
    /// In-progress staged rollout release.
    #[serde(rename = "inProgress")]
    InProgress,
    /// Halted rollout release.
    #[serde(rename = "halted")]
    Halted,
    /// Completed full rollout release.
    #[serde(rename = "completed")]
    Completed,
}

/// Localized release notes text for a specific language.
/// Authorised by EXTERNAL_APIS.txt line 134.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalizedText {
    /// BCP-47 language tag (e.g. "en-US", "es-ES").
    pub language: String,
    /// Release notes description text.
    pub text: String,
}

/// Country targeting configuration for a track release.
/// Authorised by EXTERNAL_APIS.txt line 135.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct CountryTargeting {
    /// ISO 3166-1 alpha-2 country codes targeted by this release.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub countries: Option<Vec<String>>,
    /// Whether to include the rest of the world.
    #[serde(rename = "includeRestOfWorld", skip_serializing_if = "Option::is_none")]
    pub include_rest_of_world: Option<bool>,
}

/// Individual release within a track.
/// Authorised by EXTERNAL_APIS.txt lines 133-140.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct TrackRelease {
    /// Optional human-readable release name.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    /// Version codes included in this release (represented as strings per API spec).
    #[serde(rename = "versionCodes", skip_serializing_if = "Option::is_none")]
    pub version_codes: Option<Vec<String>>,
    /// Localized release notes.
    #[serde(rename = "releaseNotes", skip_serializing_if = "Option::is_none")]
    pub release_notes: Option<Vec<LocalizedText>>,
    /// Rollout status of the release.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<ReleaseStatus>,
    /// Staged rollout fraction: strictly 0 < fraction < 1 for `inProgress` status.
    #[serde(rename = "userFraction", skip_serializing_if = "Option::is_none")]
    pub user_fraction: Option<f64>,
    /// Optional country targeting.
    #[serde(rename = "countryTargeting", skip_serializing_if = "Option::is_none")]
    pub country_targeting: Option<CountryTargeting>,
    /// In-app update priority integer (0 to 5).
    #[serde(
        rename = "inAppUpdatePriority",
        skip_serializing_if = "Option::is_none"
    )]
    pub in_app_update_priority: Option<i32>,
}

/// Track configuration object containing releases for a specific track.
/// Authorised by EXTERNAL_APIS.txt lines 132-133.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Track {
    /// Identifier of the track (e.g. "internal", "alpha", "beta", "production").
    pub track: String,
    /// List of releases configured on this track.
    pub releases: Vec<TrackRelease>,
}

/// Response returned when creating or querying an App Edit.
/// Authorised by EXTERNAL_APIS.txt lines 118-121.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppEdit {
    /// Unique identifier of the created edit.
    pub id: String,
    /// Expiry timestamp in epoch seconds (returned as a numeric string by Google Play).
    #[serde(rename = "expiryTimeSeconds", default)]
    pub expiry_time_seconds: Option<String>,
}

impl AppEdit {
    /// Parses the expiry timestamp as epoch seconds integer.
    pub fn expiry_epoch_seconds(&self) -> Option<i64> {
        self.expiry_time_seconds
            .as_ref()
            .and_then(|s| s.parse::<i64>().ok())
    }

    /// Checks if this edit has expired given the current unix timestamp.
    pub fn is_expired(&self, current_unix_time: i64) -> bool {
        match self.expiry_epoch_seconds() {
            Some(exp) => current_unix_time >= exp,
            None => false,
        }
    }
}

/// Information returned after uploading an Android App Bundle (AAB).
/// Authorised by EXTERNAL_APIS.txt line 129.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Bundle {
    /// Version code extracted from the uploaded AAB.
    #[serde(rename = "versionCode", default)]
    pub version_code: Option<i64>,
    /// SHA1 checksum of the uploaded bundle.
    #[serde(default)]
    pub sha1: Option<String>,
    /// SHA256 checksum of the uploaded bundle.
    #[serde(default)]
    pub sha256: Option<String>,
}

/// Configuration credentials for Google Play Android Publisher API.
#[derive(Clone, PartialEq, Eq)]
pub struct GooglePlayConfig {
    /// API base URL.
    pub base_url: String,
    /// Bearer access token for `https://www.googleapis.com/auth/androidpublisher`.
    pub access_token: Option<String>,
    /// Decrypted Service Account JSON credentials.
    pub service_account_json: Option<String>,
}

// Redact tokens and service account key in Debug representation
impl fmt::Debug for GooglePlayConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("GooglePlayConfig")
            .field("base_url", &self.base_url)
            .field(
                "access_token",
                &self.access_token.as_ref().map(|_| "[REDACTED]"),
            )
            .field(
                "service_account_json",
                &self.service_account_json.as_ref().map(|_| "[REDACTED]"),
            )
            .finish()
    }
}

/// Google Play Android Publisher API v3 client.
#[derive(Clone)]
pub struct GooglePlayClient {
    http: reqwest::Client,
    upload_http: reqwest::Client,
    config: Option<GooglePlayConfig>,
}

impl GooglePlayClient {
    /// Creates a new `GooglePlayClient` from typed settings and an optional pre-minted bearer token.
    pub fn new(settings: &GooglePlaySettings, access_token: Option<String>) -> Self {
        let base_url = if settings.api_url.trim().is_empty() {
            DEFAULT_GOOGLE_PLAY_BASE_URL.to_string()
        } else {
            settings.api_url.trim().trim_end_matches('/').to_string()
        };

        let token = access_token
            .map(|t| t.trim().to_string())
            .filter(|t| !t.is_empty());

        let config = token.map(|t| GooglePlayConfig {
            base_url,
            access_token: Some(t),
            service_account_json: None,
        });

        let http = reqwest::Client::builder()
            .timeout(DEFAULT_GOOGLE_PLAY_TIMEOUT)
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        let upload_http = reqwest::Client::builder()
            .timeout(BUNDLE_UPLOAD_TIMEOUT)
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        Self {
            http,
            upload_http,
            config,
        }
    }

    /// Creates a `GooglePlayClient` with an explicit base URL and bearer access token.
    pub fn from_token(base_url: impl Into<String>, access_token: impl Into<String>) -> Self {
        let base_url = base_url.into().trim().trim_end_matches('/').to_string();
        let access_token = access_token.into().trim().to_string();

        let config = Some(GooglePlayConfig {
            base_url: if base_url.is_empty() {
                DEFAULT_GOOGLE_PLAY_BASE_URL.to_string()
            } else {
                base_url
            },
            access_token: Some(access_token),
            service_account_json: None,
        });

        let http = reqwest::Client::builder()
            .timeout(DEFAULT_GOOGLE_PLAY_TIMEOUT)
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        let upload_http = reqwest::Client::builder()
            .timeout(BUNDLE_UPLOAD_TIMEOUT)
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        Self {
            http,
            upload_http,
            config,
        }
    }

    /// Creates an explicitly disabled / unconfigured `GooglePlayClient`.
    pub fn unconfigured() -> Self {
        Self {
            http: reqwest::Client::new(),
            upload_http: reqwest::Client::new(),
            config: None,
        }
    }

    /// Returns `true` if the client is configured with active credentials.
    pub fn is_configured(&self) -> bool {
        self.config
            .as_ref()
            .and_then(|c| c.access_token.as_ref())
            .is_some()
    }

    /// Validates release parameters, enforcing `userFraction` invariants.
    ///
    /// Rules authorised by EXTERNAL_APIS.txt lines 139-140:
    /// - `userFraction` must satisfy `0.0 < fraction < 1.0`.
    /// - `userFraction = 1.0` is strictly forbidden (full rollout is represented by `completed`).
    /// - `userFraction` belongs to `InProgress` status only, not `Completed`.
    pub fn validate_track_release(release: &TrackRelease) -> Result<(), GooglePlayError> {
        if let Some(fraction) = release.user_fraction {
            if fraction <= 0.0 || fraction >= 1.0 {
                return Err(GooglePlayError::InvalidUserFraction(format!(
                    "userFraction must be strictly between 0.0 and 1.0 (exclusive), got {fraction}"
                )));
            }

            if release.status == Some(ReleaseStatus::Completed) {
                return Err(GooglePlayError::InvalidUserFraction(
                    "userFraction cannot be specified for completed releases; use inProgress for staged rollouts"
                        .to_string(),
                ));
            }
        }
        Ok(())
    }

    // -------------------------------------------------------------------------
    // Endpoint URL Builders
    // -------------------------------------------------------------------------

    /// Constructs URL for creating a new edit:
    /// `POST /androidpublisher/v3/applications/{packageName}/edits`
    /// Authorised by EXTERNAL_APIS.txt line 118.
    pub fn create_edit_url(base_url: &str, package_name: &str) -> String {
        format!(
            "{}/androidpublisher/v3/applications/{}/edits",
            base_url.trim_end_matches('/'),
            package_name.trim()
        )
    }

    /// Constructs URL for querying an edit:
    /// `GET /androidpublisher/v3/applications/{packageName}/edits/{editId}`
    /// Authorised by EXTERNAL_APIS.txt line 149.
    pub fn get_edit_url(base_url: &str, package_name: &str, edit_id: &str) -> String {
        format!(
            "{}/androidpublisher/v3/applications/{}/edits/{}",
            base_url.trim_end_matches('/'),
            package_name.trim(),
            edit_id.trim()
        )
    }

    /// Constructs URL for deleting an edit:
    /// `DELETE /androidpublisher/v3/applications/{packageName}/edits/{editId}`
    /// Authorised by EXTERNAL_APIS.txt line 149.
    pub fn delete_edit_url(base_url: &str, package_name: &str, edit_id: &str) -> String {
        format!(
            "{}/androidpublisher/v3/applications/{}/edits/{}",
            base_url.trim_end_matches('/'),
            package_name.trim(),
            edit_id.trim()
        )
    }

    /// Constructs URL for uploading a bundle:
    /// `POST https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{packageName}/edits/{editId}/bundles`
    /// Authorised by EXTERNAL_APIS.txt lines 123-126.
    pub fn bundle_upload_url(
        base_url: &str,
        package_name: &str,
        edit_id: &str,
        device_tier_config_id: Option<&str>,
    ) -> String {
        let clean_base = base_url.trim_end_matches('/');
        let host = if clean_base.contains("/upload") {
            clean_base.to_string()
        } else if let Some(stripped) = clean_base.strip_prefix("https://") {
            format!("https://{}/upload", stripped)
        } else if let Some(stripped) = clean_base.strip_prefix("http://") {
            format!("http://{}/upload", stripped)
        } else {
            format!("{}/upload", clean_base)
        };

        let mut url = format!(
            "{}/androidpublisher/v3/applications/{}/edits/{}/bundles",
            host,
            package_name.trim(),
            edit_id.trim()
        );

        if let Some(tier_id) = device_tier_config_id {
            url.push_str("?deviceTierConfigId=");
            url.push_str(tier_id.trim());
        }

        url
    }

    /// Constructs URL for assigning or polling a track:
    /// `PATCH` / `PUT` / `GET /androidpublisher/v3/applications/{packageName}/edits/{editId}/tracks/{track}`
    /// Authorised by EXTERNAL_APIS.txt lines 132, 146.
    pub fn tracks_url(base_url: &str, package_name: &str, edit_id: &str, track: &str) -> String {
        format!(
            "{}/androidpublisher/v3/applications/{}/edits/{}/tracks/{}",
            base_url.trim_end_matches('/'),
            package_name.trim(),
            edit_id.trim(),
            track.trim()
        )
    }

    /// Constructs URL for validating an edit:
    /// `POST /androidpublisher/v3/applications/{packageName}/edits/{editId}:validate`
    /// Authorised by EXTERNAL_APIS.txt line 150.
    pub fn validate_edit_url(base_url: &str, package_name: &str, edit_id: &str) -> String {
        format!(
            "{}/androidpublisher/v3/applications/{}/edits/{}:validate",
            base_url.trim_end_matches('/'),
            package_name.trim(),
            edit_id.trim()
        )
    }

    /// Constructs URL for committing an edit:
    /// `POST /androidpublisher/v3/applications/{packageName}/edits/{editId}:commit`
    /// Authorised by EXTERNAL_APIS.txt line 143.
    pub fn commit_edit_url(base_url: &str, package_name: &str, edit_id: &str) -> String {
        format!(
            "{}/androidpublisher/v3/applications/{}/edits/{}:commit",
            base_url.trim_end_matches('/'),
            package_name.trim(),
            edit_id.trim()
        )
    }

    // -------------------------------------------------------------------------
    // API Lifecycle Operations
    // -------------------------------------------------------------------------

    /// Builds authorization headers.
    fn build_headers(&self, config: &GooglePlayConfig) -> Result<HeaderMap, GooglePlayError> {
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));

        if let Some(token) = &config.access_token {
            let auth_val = format!("Bearer {token}");
            let mut auth_header = HeaderValue::from_str(&auth_val)
                .map_err(|e| GooglePlayError::Serialization(format!("Invalid auth header: {e}")))?;
            auth_header.set_sensitive(true);
            headers.insert(AUTHORIZATION, auth_header);
        } else {
            return Err(GooglePlayError::NotConfigured(
                "No active access token configured for Google Play client".to_string(),
            ));
        }

        Ok(headers)
    }

    /// Creates a new App Edit.
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 117-121 (`POST /androidpublisher/v3/applications/{packageName}/edits`).
    pub async fn create_edit(&self, package_name: &str) -> Result<AppEdit, GooglePlayError> {
        let config = self.config.as_ref().ok_or_else(|| {
            GooglePlayError::NotConfigured("Google Play client is not configured".to_string())
        })?;

        let url = Self::create_edit_url(&config.base_url, package_name);
        let headers = self.build_headers(config)?;

        let response = self
            .http
            .post(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| GooglePlayError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(GooglePlayError::Api {
                status,
                message: body,
            });
        }

        let edit: AppEdit = response.json().await.map_err(|e| {
            GooglePlayError::Serialization(format!("Failed parsing AppEdit response: {e}"))
        })?;

        Ok(edit)
    }

    /// Fetches metadata for an existing App Edit.
    ///
    /// Authorised by EXTERNAL_APIS.txt line 149 (`GET /androidpublisher/v3/applications/{packageName}/edits/{editId}`).
    pub async fn get_edit(
        &self,
        package_name: &str,
        edit_id: &str,
    ) -> Result<AppEdit, GooglePlayError> {
        let config = self.config.as_ref().ok_or_else(|| {
            GooglePlayError::NotConfigured("Google Play client is not configured".to_string())
        })?;

        let url = Self::get_edit_url(&config.base_url, package_name, edit_id);
        let headers = self.build_headers(config)?;

        let response = self
            .http
            .get(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| GooglePlayError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(GooglePlayError::Api {
                status,
                message: body,
            });
        }

        let edit: AppEdit = response.json().await.map_err(|e| {
            GooglePlayError::Serialization(format!("Failed parsing AppEdit response: {e}"))
        })?;

        Ok(edit)
    }

    /// Deletes an App Edit.
    ///
    /// Authorised by EXTERNAL_APIS.txt line 149 (`DELETE /androidpublisher/v3/applications/{packageName}/edits/{editId}`).
    pub async fn delete_edit(
        &self,
        package_name: &str,
        edit_id: &str,
    ) -> Result<(), GooglePlayError> {
        let config = self.config.as_ref().ok_or_else(|| {
            GooglePlayError::NotConfigured("Google Play client is not configured".to_string())
        })?;

        let url = Self::delete_edit_url(&config.base_url, package_name, edit_id);
        let headers = self.build_headers(config)?;

        let response = self
            .http
            .delete(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| GooglePlayError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(GooglePlayError::Api {
                status,
                message: body,
            });
        }

        Ok(())
    }

    /// Uploads an Android App Bundle (`.aab`) to the edit.
    ///
    /// Uses the dedicated `/upload/...` host path and enforces [`BUNDLE_UPLOAD_TIMEOUT`] (>= 2 minutes).
    /// Authorised by EXTERNAL_APIS.txt lines 123-129.
    pub async fn upload_bundle(
        &self,
        package_name: &str,
        edit_id: &str,
        bundle_bytes: Bytes,
        device_tier_config_id: Option<&str>,
    ) -> Result<Bundle, GooglePlayError> {
        let config = self.config.as_ref().ok_or_else(|| {
            GooglePlayError::NotConfigured("Google Play client is not configured".to_string())
        })?;

        let url = Self::bundle_upload_url(
            &config.base_url,
            package_name,
            edit_id,
            device_tier_config_id,
        );

        let mut headers = HeaderMap::new();
        headers.insert(
            CONTENT_TYPE,
            HeaderValue::from_static("application/octet-stream"),
        );

        if let Some(token) = &config.access_token {
            let auth_val = format!("Bearer {token}");
            let mut auth_header = HeaderValue::from_str(&auth_val)
                .map_err(|e| GooglePlayError::Serialization(format!("Invalid auth header: {e}")))?;
            auth_header.set_sensitive(true);
            headers.insert(AUTHORIZATION, auth_header);
        }

        let response = self
            .upload_http
            .post(&url)
            .headers(headers)
            .body(bundle_bytes)
            .send()
            .await
            .map_err(|e| GooglePlayError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(GooglePlayError::Api {
                status,
                message: body,
            });
        }

        let bundle: Bundle = response.json().await.map_err(|e| {
            GooglePlayError::Serialization(format!("Failed parsing Bundle response: {e}"))
        })?;

        Ok(bundle)
    }

    /// Assigns releases to a track (e.g. "internal", "alpha", "beta", "production").
    ///
    /// Validates `userFraction` invariants before sending.
    /// Authorised by EXTERNAL_APIS.txt lines 131-140 (`PUT /androidpublisher/v3/applications/{packageName}/edits/{editId}/tracks/{track}`).
    pub async fn assign_track(
        &self,
        package_name: &str,
        edit_id: &str,
        track_name: &str,
        release: TrackRelease,
    ) -> Result<Track, GooglePlayError> {
        Self::validate_track_release(&release)?;

        let config = self.config.as_ref().ok_or_else(|| {
            GooglePlayError::NotConfigured("Google Play client is not configured".to_string())
        })?;

        let url = Self::tracks_url(&config.base_url, package_name, edit_id, track_name);
        let headers = self.build_headers(config)?;

        let payload = Track {
            track: track_name.to_string(),
            releases: vec![release],
        };

        let response = self
            .http
            .put(&url)
            .headers(headers)
            .json(&payload)
            .send()
            .await
            .map_err(|e| GooglePlayError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(GooglePlayError::Api {
                status,
                message: body,
            });
        }

        let track: Track = response.json().await.map_err(|e| {
            GooglePlayError::Serialization(format!("Failed parsing Track response: {e}"))
        })?;

        Ok(track)
    }

    /// Polls release status for a specific track.
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 145-147 (`GET /androidpublisher/v3/applications/{packageName}/edits/{editId}/tracks/{track}`).
    pub async fn get_track(
        &self,
        package_name: &str,
        edit_id: &str,
        track_name: &str,
    ) -> Result<Track, GooglePlayError> {
        let config = self.config.as_ref().ok_or_else(|| {
            GooglePlayError::NotConfigured("Google Play client is not configured".to_string())
        })?;

        let url = Self::tracks_url(&config.base_url, package_name, edit_id, track_name);
        let headers = self.build_headers(config)?;

        let response = self
            .http
            .get(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| GooglePlayError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(GooglePlayError::Api {
                status,
                message: body,
            });
        }

        let track: Track = response.json().await.map_err(|e| {
            GooglePlayError::Serialization(format!("Failed parsing Track response: {e}"))
        })?;

        Ok(track)
    }

    /// Validates an App Edit without committing it.
    ///
    /// Authorised by EXTERNAL_APIS.txt line 150 (`POST /androidpublisher/v3/applications/{packageName}/edits/{editId}:validate`).
    pub async fn validate_edit(
        &self,
        package_name: &str,
        edit_id: &str,
    ) -> Result<(), GooglePlayError> {
        let config = self.config.as_ref().ok_or_else(|| {
            GooglePlayError::NotConfigured("Google Play client is not configured".to_string())
        })?;

        let url = Self::validate_edit_url(&config.base_url, package_name, edit_id);
        let headers = self.build_headers(config)?;

        let response = self
            .http
            .post(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| GooglePlayError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(GooglePlayError::Api {
                status,
                message: body,
            });
        }

        Ok(())
    }

    /// Commits an App Edit atomically.
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 143-144 (`POST /androidpublisher/v3/applications/{packageName}/edits/{editId}:commit`).
    pub async fn commit_edit(
        &self,
        package_name: &str,
        edit_id: &str,
    ) -> Result<AppEdit, GooglePlayError> {
        let config = self.config.as_ref().ok_or_else(|| {
            GooglePlayError::NotConfigured("Google Play client is not configured".to_string())
        })?;

        let url = Self::commit_edit_url(&config.base_url, package_name, edit_id);
        let headers = self.build_headers(config)?;

        let response = self
            .http
            .post(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| GooglePlayError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(GooglePlayError::Api {
                status,
                message: body,
            });
        }

        let edit: AppEdit = response.json().await.map_err(|e| {
            GooglePlayError::Serialization(format!("Failed parsing AppEdit response: {e}"))
        })?;

        Ok(edit)
    }

    /// Mints a fresh Google OAuth2 access token from a service account key JSON.
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 107-110.
    pub async fn mint_service_account_token(
        &self,
        _service_account_json: &str,
    ) -> Result<String, GooglePlayError> {
        // TODO(spec): needs crate jsonwebtoken for RS256 JWT signing of Google OAuth2 service account assertions; reviewer must add it to Cargo.toml
        Err(GooglePlayError::Auth(
            "Service account token minting requires RS256 JWT signing crate (jsonwebtoken)"
                .to_string(),
        ))
    }
}
