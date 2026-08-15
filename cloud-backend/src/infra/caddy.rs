//! Caddy reverse proxy admin API client.
//!
//! # Architecture & Scope
//!
//! Caddy fronts deployed web applications and custom domains. This client dynamically
//! provisions, updates, and tears down site blocks via Caddy's RESTful Admin API:
//!
//! ```text
//! Base URL: http://localhost:2019 (configurable via BloomSettings / CaddySettings)
//! ```
//!
//! # Safety & Tenant Isolation (Absolute Rule)
//!
//! **NEVER CALL `POST /load`.**
//!
//! `POST /load` replaces the entire active Caddy configuration and would instantly wipe
//! out every other tenant's site configuration.
//!
//! All mutation operations in this client strictly use scoped endpoints:
//! - Direct object addressing: `/id/<@id>/...`
//! - Specific config paths: `/config/<path>`
//!
//! Every site block managed by Bloom Cloud is assigned a stable `@id` derived from the
//! deployment's public UUID (via [`caddy_site_id`]).
//!
//! # Array Expansion
//!
//! When a path ends in `/...` and points at an array, `POST` appends elements individually
//! per Caddy API specifications.

use std::fmt;
use std::time::Duration;

use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE};
use serde::{Deserialize, Serialize};

use crate::settings::CaddySettings;

/// Default HTTP request timeout for Caddy admin API requests (10 seconds).
pub const DEFAULT_CADDY_TIMEOUT: Duration = Duration::from_secs(10);

/// Errors arising from Caddy admin API operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CaddyError {
    /// Caddy client configuration error or invalid URL.
    Config(String),
    /// Serialization or JSON marshalling error.
    Serialization(String),
    /// HTTP or network transport failure.
    Http(String),
    /// Caddy Admin API returned a non-success HTTP status code.
    Api {
        /// HTTP status code returned by Caddy.
        status: u16,
        /// Response body or error message from Caddy.
        message: String,
    },
}

impl fmt::Display for CaddyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CaddyError::Config(msg) => write!(f, "Caddy configuration error: {msg}"),
            CaddyError::Serialization(msg) => write!(f, "Caddy serialization error: {msg}"),
            CaddyError::Http(msg) => write!(f, "Caddy HTTP transport error: {msg}"),
            CaddyError::Api { status, message } => {
                write!(f, "Caddy Admin API error (HTTP {status}): {message}")
            }
        }
    }
}

impl std::error::Error for CaddyError {}

/// Derives a stable, unique `@id` tag for addressing a site block in Caddy.
///
/// Uses the deployment or domain's public UUID string: `bloom-site-{deployment_public_id}`.
/// Authorised by EXTERNAL_APIS.txt lines 75-79.
pub fn caddy_site_id(deployment_public_id: &str) -> String {
    format!("bloom-site-{}", deployment_public_id.trim())
}

/// Static file server configuration for Caddy `file_server` handler.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaddyFileServerHandler {
    /// Handler discriminator (`file_server`).
    pub handler: String,
    /// Root directory path for static files.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub root: Option<String>,
    /// Index filenames.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub index_names: Option<Vec<String>>,
}

/// Reverse proxy upstream configuration for Caddy `reverse_proxy` handler.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaddyUpstream {
    /// Dial address (e.g. `127.0.0.1:8080`).
    pub dial: String,
}

/// Reverse proxy handler configuration.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaddyReverseProxyHandler {
    /// Handler discriminator (`reverse_proxy`).
    pub handler: String,
    /// Upstream targets.
    pub upstreams: Vec<CaddyUpstream>,
}

/// Host matching condition in Caddy route.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaddyHostMatcher {
    /// List of hostnames (domains / subdomains) to match.
    pub host: Vec<String>,
}

/// Match rule object within a Caddy route.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaddyMatchRule {
    /// Host matcher rule.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub host: Option<Vec<String>>,
}

/// Route definition in Caddy HTTP server.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaddyRoute {
    /// Match conditions for this route.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub r#match: Option<Vec<CaddyMatchRule>>,
    /// Ordered list of handlers executing for matching requests.
    #[serde(default)]
    pub handle: Vec<serde_json::Value>,
    /// Terminal route flag.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub terminal: Option<bool>,
}

/// Complete site block payload registered under Caddy config.
///
/// Embeds `"@id"` so that it can be addressed, patched, and deleted directly
/// without walking or replacing the overall config tree.
/// Authorised by EXTERNAL_APIS.txt lines 75-79.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaddySiteBlock {
    /// Unique stable identifier for scoped addressing (`/id/<@id>/...`).
    #[serde(rename = "@id")]
    pub id: String,
    /// Host matching rule.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub r#match: Option<Vec<CaddyMatchRule>>,
    /// Handler pipeline.
    #[serde(default)]
    pub handle: Vec<serde_json::Value>,
    /// Terminal flag.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub terminal: Option<bool>,
}

/// Caddy Admin API client for dynamic route management.
#[derive(Clone)]
pub struct CaddyClient {
    http: reqwest::Client,
    admin_url: String,
    admin_token: Option<String>,
}

impl CaddyClient {
    /// Creates a new `CaddyClient` from typed application settings.
    pub fn new(settings: &CaddySettings) -> Self {
        let admin_url = settings.admin_url.trim().trim_end_matches('/').to_string();
        let admin_token = settings
            .admin_token
            .as_ref()
            .map(|t| t.trim().to_string())
            .filter(|t| !t.is_empty());

        let http = reqwest::Client::builder()
            .timeout(DEFAULT_CADDY_TIMEOUT)
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        Self {
            http,
            admin_url,
            admin_token,
        }
    }

    /// Creates a `CaddyClient` pointing to an explicit URL with optional bearer token.
    pub fn from_url(admin_url: impl Into<String>, admin_token: Option<String>) -> Self {
        let admin_url = admin_url.into().trim().trim_end_matches('/').to_string();
        let admin_token = admin_token
            .map(|t| t.trim().to_string())
            .filter(|t| !t.is_empty());

        let http = reqwest::Client::builder()
            .timeout(DEFAULT_CADDY_TIMEOUT)
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        Self {
            http,
            admin_url,
            admin_token,
        }
    }

    /// Returns the configured Admin API base URL.
    pub fn admin_url(&self) -> &str {
        &self.admin_url
    }

    /// Constructs the scoped URL for addressing an `@id` tagged object.
    ///
    /// Example: `http://localhost:2019/id/bloom-site-123`
    /// Authorised by EXTERNAL_APIS.txt line 77.
    pub fn id_endpoint_url(&self, id: &str) -> String {
        format!("{}/id/{}", self.admin_url, id.trim())
    }

    /// Constructs the scoped URL for addressing a subpath of an `@id` tagged object.
    ///
    /// Example: `http://localhost:2019/id/bloom-site-123/handle`
    /// Authorised by EXTERNAL_APIS.txt line 77.
    pub fn id_subpath_endpoint_url(&self, id: &str, path: &str) -> String {
        let clean_path = path.trim().trim_start_matches('/');
        format!("{}/id/{}/{}", self.admin_url, id.trim(), clean_path)
    }

    /// Constructs a config path URL.
    ///
    /// Example: `http://localhost:2019/config/apps/http/servers/srv0/routes/...`
    /// Authorised by EXTERNAL_APIS.txt lines 68-72.
    pub fn config_endpoint_url(&self, path: &str) -> String {
        let clean_path = path.trim().trim_start_matches('/');
        format!("{}/config/{}", self.admin_url, clean_path)
    }

    /// Builds default request headers including Content-Type and optional Bearer token.
    fn build_headers(&self) -> Result<HeaderMap, CaddyError> {
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));

        if let Some(token) = &self.admin_token {
            let auth_val = format!("Bearer {token}");
            let mut auth_header = HeaderValue::from_str(&auth_val)
                .map_err(|e| CaddyError::Config(format!("Invalid admin auth token header: {e}")))?;
            auth_header.set_sensitive(true);
            headers.insert(AUTHORIZATION, auth_header);
        }

        Ok(headers)
    }

    /// Gets configuration at a specific config path.
    ///
    /// Authorised by EXTERNAL_APIS.txt line 68 (`GET /config/[path]`).
    pub async fn get_config(&self, path: &str) -> Result<serde_json::Value, CaddyError> {
        let url = self.config_endpoint_url(path);
        let headers = self.build_headers()?;

        let response = self
            .http
            .get(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| CaddyError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(CaddyError::Api {
                status,
                message: body,
            });
        }

        let json = response.json().await.map_err(|e| {
            CaddyError::Serialization(format!("Failed parsing Caddy JSON response: {e}"))
        })?;

        Ok(json)
    }

    /// Gets an object directly by its `@id`.
    ///
    /// Authorised by EXTERNAL_APIS.txt line 77 (`GET /id/<@id>`).
    pub async fn get_by_id(&self, id: &str) -> Result<serde_json::Value, CaddyError> {
        let url = self.id_endpoint_url(id);
        let headers = self.build_headers()?;

        let response = self
            .http
            .get(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| CaddyError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(CaddyError::Api {
                status,
                message: body,
            });
        }

        let json = response.json().await.map_err(|e| {
            CaddyError::Serialization(format!("Failed parsing Caddy JSON response: {e}"))
        })?;

        Ok(json)
    }

    /// Adds a new site block to Caddy routes array.
    ///
    /// Appends the site block using `POST /config/[routes_path]/...`.
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 69, 75-79, 81-86.
    pub async fn add_site_block(
        &self,
        routes_path: &str,
        site_block: &CaddySiteBlock,
    ) -> Result<(), CaddyError> {
        let clean_path = routes_path.trim().trim_end_matches('/');
        let path = if clean_path.ends_with("/...") {
            clean_path.to_string()
        } else {
            format!("{clean_path}/...")
        };

        let url = self.config_endpoint_url(&path);
        let headers = self.build_headers()?;

        let response = self
            .http
            .post(&url)
            .headers(headers)
            .json(site_block)
            .send()
            .await
            .map_err(|e| CaddyError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(CaddyError::Api {
                status,
                message: body,
            });
        }

        Ok(())
    }

    /// Updates or replaces an existing site block addressed by its `@id`.
    ///
    /// Uses `PATCH /id/<@id>`.
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 71, 75-79.
    pub async fn update_site_block(
        &self,
        site_id: &str,
        site_block: &CaddySiteBlock,
    ) -> Result<(), CaddyError> {
        let url = self.id_endpoint_url(site_id);
        let headers = self.build_headers()?;

        let response = self
            .http
            .patch(&url)
            .headers(headers)
            .json(site_block)
            .send()
            .await
            .map_err(|e| CaddyError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(CaddyError::Api {
                status,
                message: body,
            });
        }

        Ok(())
    }

    /// Removes a site block addressed by its `@id`.
    ///
    /// Uses `DELETE /id/<@id>`.
    ///
    /// Authorised by EXTERNAL_APIS.txt lines 72, 75-79.
    pub async fn remove_site_block(&self, site_id: &str) -> Result<(), CaddyError> {
        let url = self.id_endpoint_url(site_id);
        let headers = self.build_headers()?;

        let response = self
            .http
            .delete(&url)
            .headers(headers)
            .send()
            .await
            .map_err(|e| CaddyError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(CaddyError::Api {
                status,
                message: body,
            });
        }

        Ok(())
    }

    /// Inserts a value strictly at a specific path or array index using PUT.
    ///
    /// Authorised by EXTERNAL_APIS.txt line 70 (`PUT /config/[path]`).
    pub async fn put_config<T: Serialize>(
        &self,
        path: &str,
        payload: &T,
    ) -> Result<(), CaddyError> {
        let url = self.config_endpoint_url(path);
        let headers = self.build_headers()?;

        let response = self
            .http
            .put(&url)
            .headers(headers)
            .json(payload)
            .send()
            .await
            .map_err(|e| CaddyError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(CaddyError::Api {
                status,
                message: body,
            });
        }

        Ok(())
    }

    /// Converts a raw Caddy config to JSON without loading it using POST /adapt.
    ///
    /// Authorised by EXTERNAL_APIS.txt line 73 (`POST /adapt`).
    pub async fn adapt_config(&self, config_body: &str) -> Result<serde_json::Value, CaddyError> {
        let url = format!("{}/adapt", self.admin_url);
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("text/caddyfile"));

        if let Some(token) = &self.admin_token {
            let auth_val = format!("Bearer {token}");
            let mut auth_header = HeaderValue::from_str(&auth_val)
                .map_err(|e| CaddyError::Config(format!("Invalid admin auth token header: {e}")))?;
            auth_header.set_sensitive(true);
            headers.insert(AUTHORIZATION, auth_header);
        }

        let response = self
            .http
            .post(&url)
            .headers(headers)
            .body(config_body.to_string())
            .send()
            .await
            .map_err(|e| CaddyError::Http(e.to_string()))?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(CaddyError::Api {
                status,
                message: body,
            });
        }

        let json = response.json().await.map_err(|e| {
            CaddyError::Serialization(format!("Failed parsing Caddy JSON response: {e}"))
        })?;

        Ok(json)
    }
}
