//! Cloudflare CDN cache invalidation client.
//!
//! # Architecture & Scope
//!
//! Provides cache invalidation for web deployments hosted on Cloudflare zones.
//!
//! Invalidation requests are authenticated using scoped API tokens against Cloudflare's
//! Client v4 API:
//!
//! ```text
//! POST https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache
//! ```
//!
//! # Safety & Shared Zone Isolation
//!
//! A web deployment writes every file under one storage prefix, so **purge by prefix**
//! is the standard operation. Purging by prefix invalidates the target deployment without
//! enumerating files or evicting unrelated deployments.
//!
//! Purge-all (`purge_everything: true`) MUST NOT be used during normal deployments as it
//! evicts all cached assets across all tenants sharing the zone.
//!
//! # Limits & Chunking
//!
//! Cloudflare enforces hard limits per purge request:
//! - **Max 30 prefixes** per purge-by-prefix request ([`MAX_PREFIXES_PER_PURGE`]).
//! - **Max 100 URLs** per purge-by-URL request ([`MAX_URLS_PER_PURGE`]).
//!
//! Requests exceeding these limits are automatically chunked into sequential batches.

use std::fmt;
use std::time::Duration;

use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE};
use serde::{Deserialize, Serialize};

use crate::settings::CloudflareSettings;

/// Hard limit on the number of prefixes in a single purge request.
/// Authorised by EXTERNAL_APIS.txt line 40 ("Max 30 prefixes per purge-by-prefix request").
pub const MAX_PREFIXES_PER_PURGE: usize = 30;

/// Hard limit on the number of URLs in a single purge request.
/// Authorised by EXTERNAL_APIS.txt line 38 ("Max 100 URLs per single-file purge request").
pub const MAX_URLS_PER_PURGE: usize = 100;

/// Default HTTP request timeout for CDN cache purge requests (15 seconds).
pub const DEFAULT_PURGE_TIMEOUT: Duration = Duration::from_secs(15);

/// Errors arising from CDN cache invalidation operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CdnError {
    /// CDN client or credentials are not configured.
    NotConfigured(String),
    /// Request serialization error.
    Serialization(String),
    /// HTTP or network transport failure.
    Http(String),
    /// Cloudflare API returned failure envelope or error code.
    Api {
        /// HTTP status code or general failure label.
        status: u16,
        /// List of vendor error envelopes returned by Cloudflare.
        errors: Vec<CloudflareApiError>,
    },
}

impl fmt::Display for CdnError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CdnError::NotConfigured(msg) => write!(f, "CDN invalidation not configured: {msg}"),
            CdnError::Serialization(msg) => write!(f, "CDN payload serialization error: {msg}"),
            CdnError::Http(msg) => write!(f, "CDN HTTP transport error: {msg}"),
            CdnError::Api { status, errors } => {
                let err_details: Vec<String> = errors
                    .iter()
                    .map(|e| format!("[code {}] {}", e.code, e.message))
                    .collect();
                write!(
                    f,
                    "Cloudflare CDN API error (HTTP {status}): {}",
                    if err_details.is_empty() {
                        "unknown API failure".to_string()
                    } else {
                        err_details.join("; ")
                    }
                )
            }
        }
    }
}

impl std::error::Error for CdnError {}

/// Individual error object returned in Cloudflare API responses.
/// Authorised by EXTERNAL_APIS.txt line 33.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CloudflareApiError {
    /// Vendor error code integer.
    pub code: i64,
    /// Human-readable error message.
    pub message: String,
    /// Optional documentation URL for the error.
    pub documentation_url: Option<String>,
}

/// Individual informational message object returned in Cloudflare API responses.
/// Authorised by EXTERNAL_APIS.txt line 34.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CloudflareApiMessage {
    /// Vendor message code integer.
    pub code: i64,
    /// Human-readable informational message.
    pub message: String,
    /// Optional documentation URL.
    pub documentation_url: Option<String>,
}

/// Result payload returned on successful Cloudflare purge response.
/// Authorised by EXTERNAL_APIS.txt line 32.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CloudflarePurgeResult {
    /// Zone ID returned in the result payload.
    pub id: Option<String>,
}

/// Standard Cloudflare Client v4 API envelope.
/// Authorised by EXTERNAL_APIS.txt lines 30-35.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CloudflareResponse {
    /// Boolean indicating whether the purge request succeeded.
    pub success: bool,
    /// Result payload if present.
    pub result: Option<CloudflarePurgeResult>,
    /// Error items if any occurred.
    #[serde(default)]
    pub errors: Vec<CloudflareApiError>,
    /// Informational messages if any.
    #[serde(default)]
    pub messages: Vec<CloudflareApiMessage>,
}

/// Request payload for purging cache by prefix.
/// Authorised by EXTERNAL_APIS.txt line 25.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PurgeByPrefixRequest {
    /// List of prefix paths to invalidate.
    pub prefixes: Vec<String>,
}

/// Request payload for purging cache by individual file URLs.
/// Authorised by EXTERNAL_APIS.txt line 24.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PurgeByFilesRequest {
    /// List of exact asset URLs to invalidate.
    pub files: Vec<String>,
}

/// Request payload for purging everything in a zone.
/// Authorised by EXTERNAL_APIS.txt line 26.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PurgeEverythingRequest {
    /// Boolean flag to purge all assets in the zone.
    pub purge_everything: bool,
}

/// Result outcome from executing a purge operation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PurgeOutcome {
    /// Purge was executed and succeeded across all batches.
    Purged {
        /// Number of request batches issued.
        batches_sent: usize,
    },
    /// Purge was skipped because CDN invalidation is unconfigured.
    Skipped {
        /// Reason why purge was skipped.
        reason: String,
    },
}

/// Configuration credentials for Cloudflare CDN client.
#[derive(Clone)]
struct CdnConfig {
    api_token: String,
    zone_id: String,
}

/// Cloudflare CDN cache invalidation client.
#[derive(Clone)]
pub struct CdnClient {
    http: reqwest::Client,
    config: Option<CdnConfig>,
}

impl CdnClient {
    /// Creates a new `CdnClient` from typed application settings.
    ///
    /// If `api_token` or `zone_id` is unset or empty, the client enters an explicit
    /// unconfigured state: calls to purge will skip safely with an informational log
    /// rather than erroring or panicking.
    pub fn new(settings: &CloudflareSettings) -> Self {
        let config = match (&settings.api_token, &settings.zone_id) {
            (Some(token), Some(zone)) if !token.trim().is_empty() && !zone.trim().is_empty() => {
                Some(CdnConfig {
                    api_token: token.trim().to_string(),
                    zone_id: zone.trim().to_string(),
                })
            }
            _ => None,
        };

        let http = reqwest::Client::builder()
            .timeout(DEFAULT_PURGE_TIMEOUT)
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        Self { http, config }
    }

    /// Creates an explicitly disabled / mock `CdnClient` for testing.
    pub fn unconfigured() -> Self {
        Self {
            http: reqwest::Client::new(),
            config: None,
        }
    }

    /// Returns `true` if the client has valid credentials and zone configured.
    pub fn is_configured(&self) -> bool {
        self.config.is_some()
    }

    /// Helper to construct the purge cache endpoint URL for a given zone ID.
    /// Authorised by EXTERNAL_APIS.txt line 19.
    pub fn purge_endpoint_url(zone_id: &str) -> String {
        format!("https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache")
    }

    /// Chunks a slice of items into batches of `max_batch_size`.
    pub fn chunk_items<T: Clone>(items: &[T], max_batch_size: usize) -> Vec<Vec<T>> {
        if items.is_empty() || max_batch_size == 0 {
            return Vec::new();
        }
        items
            .chunks(max_batch_size)
            .map(|chunk| chunk.to_vec())
            .collect()
    }

    /// Purges cache for the given prefix paths.
    ///
    /// Web deployments write assets under a single storage prefix, making this the
    /// primary invalidation entry point.
    ///
    /// Invalidation requests are automatically chunked into batches of at most
    /// [`MAX_PREFIXES_PER_PURGE`] (30 prefixes) per request.
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 19-21, 25, 30-35, 40.
    pub async fn purge_prefixes(&self, prefixes: &[String]) -> Result<PurgeOutcome, CdnError> {
        if prefixes.is_empty() {
            return Ok(PurgeOutcome::Purged { batches_sent: 0 });
        }

        let config = match &self.config {
            Some(cfg) => cfg,
            None => {
                eprintln!(
                    "Cloudflare CDN invalidation skipped: api_token or zone_id is not configured"
                );
                return Ok(PurgeOutcome::Skipped {
                    reason: "api_token or zone_id is not configured".to_string(),
                });
            }
        };

        let batches = Self::chunk_items(prefixes, MAX_PREFIXES_PER_PURGE);
        let batches_count = batches.len();

        for batch in batches {
            let body = PurgeByPrefixRequest { prefixes: batch };
            self.send_purge_request(config, &body).await?;
        }

        Ok(PurgeOutcome::Purged {
            batches_sent: batches_count,
        })
    }

    /// Purges cache for the given specific file URLs.
    ///
    /// Invalidation requests are automatically chunked into batches of at most
    /// [`MAX_URLS_PER_PURGE`] (100 URLs) per request.
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 19-21, 24, 30-35, 38.
    pub async fn purge_files(&self, urls: &[String]) -> Result<PurgeOutcome, CdnError> {
        if urls.is_empty() {
            return Ok(PurgeOutcome::Purged { batches_sent: 0 });
        }

        let config = match &self.config {
            Some(cfg) => cfg,
            None => {
                eprintln!(
                    "Cloudflare CDN invalidation skipped: api_token or zone_id is not configured"
                );
                return Ok(PurgeOutcome::Skipped {
                    reason: "api_token or zone_id is not configured".to_string(),
                });
            }
        };

        let batches = Self::chunk_items(urls, MAX_URLS_PER_PURGE);
        let batches_count = batches.len();

        for batch in batches {
            let body = PurgeByFilesRequest { files: batch };
            self.send_purge_request(config, &body).await?;
        }

        Ok(PurgeOutcome::Purged {
            batches_sent: batches_count,
        })
    }

    /// Purges all cached assets in the zone (`purge_everything: true`).
    ///
    /// # Safety Warning
    ///
    /// **DO NOT CALL THIS DURING NORMAL DEPLOYMENTS.**
    ///
    /// Calling `purge_everything` evicts the entire cache of the shared zone,
    /// degrading performance for all tenant applications simultaneously. Web
    /// deployments should always use [`purge_prefixes`](Self::purge_prefixes).
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 19-21, 26, 30-35, 46-48.
    pub async fn dangerous_purge_zone_everything(&self) -> Result<PurgeOutcome, CdnError> {
        let config = match &self.config {
            Some(cfg) => cfg,
            None => {
                eprintln!(
                    "Cloudflare CDN invalidation skipped: api_token or zone_id is not configured"
                );
                return Ok(PurgeOutcome::Skipped {
                    reason: "api_token or zone_id is not configured".to_string(),
                });
            }
        };

        let body = PurgeEverythingRequest {
            purge_everything: true,
        };

        self.send_purge_request(config, &body).await?;

        Ok(PurgeOutcome::Purged { batches_sent: 1 })
    }

    /// Internal helper to send and validate a Cloudflare purge request.
    async fn send_purge_request<T: Serialize>(
        &self,
        config: &CdnConfig,
        body: &T,
    ) -> Result<CloudflareResponse, CdnError> {
        let url = Self::purge_endpoint_url(&config.zone_id);

        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        let auth_val = format!("Bearer {}", config.api_token);
        let mut auth_header = HeaderValue::from_str(&auth_val)
            .map_err(|e| CdnError::Serialization(format!("Invalid auth header: {e}")))?;
        auth_header.set_sensitive(true);
        headers.insert(AUTHORIZATION, auth_header);

        let response = self
            .http
            .post(&url)
            .headers(headers)
            .json(body)
            .send()
            .await
            .map_err(|e| CdnError::Http(e.to_string()))?;

        let status = response.status().as_u16();

        let parsed_envelope: CloudflareResponse = response
            .json()
            .await
            .map_err(|e| CdnError::Http(format!("Failed parsing response envelope: {e}")))?;

        // Cloudflare returns success: false even on HTTP 200 when errors occur
        if !parsed_envelope.success {
            return Err(CdnError::Api {
                status,
                errors: parsed_envelope.errors,
            });
        }

        Ok(parsed_envelope)
    }
}
