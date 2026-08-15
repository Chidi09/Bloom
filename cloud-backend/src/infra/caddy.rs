//! Caddy reverse proxy admin API client and automatic TLS/ACME configuration.
//!
//! # Architecture & Scope
//!
//! Caddy fronts deployed web applications and custom domains. This client dynamically
//! provisions, updates, and tears down site blocks and TLS automation policies via
//! Caddy's RESTful Admin API:
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
//! deployment or domain's public UUID (via [`caddy_site_id`]).
//!
//! # Automatic HTTPS & ACME Policy Architecture (Phase 12)
//!
//! Caddy automatically provisions certificates for qualifying hostnames configured in
//! routes. For custom domains requiring wildcard certificates (`*.domain.com`) or apex
//! domains without open inbound port 80/443, Caddy uses the ACME DNS-01 challenge via
//! TLS automation policies registered under `/config/apps/tls/automation/policies/...`.
//!
//! # Security Rule (Strictly Enforced in Code)
//!
//! **ONLY VERIFIED DOMAINS ARE EVER WRITTEN INTO THE CADDY CONFIGURATION.**
//!
//! Writing an unverified domain to the edge reverse proxy exposes Bloom Cloud to open-redirect
//! attacks and consumes public ACME CA rate limits. Every provisioning path in this module
//! validates verification status before dispatching API requests.

use std::fmt;
use std::time::Duration;

use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE};
use serde::{Deserialize, Serialize};

use crate::settings::CaddySettings;

/// Default HTTP request timeout for Caddy admin API requests (10 seconds).
pub const DEFAULT_CADDY_TIMEOUT: Duration = Duration::from_secs(10);

/// Default Caddy routes configuration path.
pub const DEFAULT_CADDY_ROUTES_PATH: &str = "apps/http/servers/srv0/routes";

/// Default Caddy TLS automation policies configuration path.
pub const DEFAULT_CADDY_TLS_POLICIES_PATH: &str = "apps/tls/automation/policies";

/// Errors arising from Caddy admin API operations and validation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CaddyError {
    /// Caddy client configuration error or invalid URL.
    Config(String),
    /// Serialization or JSON marshalling error.
    Serialization(String),
    /// HTTP or network transport failure.
    Http(String),
    /// Security rule violation (e.g. attempting to provision an unverified domain).
    SecurityViolation(String),
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
            CaddyError::SecurityViolation(msg) => write!(f, "Caddy security violation: {msg}"),
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
pub fn caddy_site_id(deployment_public_id: &str) -> String {
    format!("bloom-site-{}", deployment_public_id.trim())
}

/// Derives a stable, unique `@id` tag for addressing a custom domain in Caddy.
pub fn caddy_custom_domain_id(domain_public_id: &str) -> String {
    format!("bloom-domain-{}", domain_public_id.trim())
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

// ---------------------------------------------------------------------------
// TLS Automation & ACME Configuration Data Structures
// Verified against real Caddy JSON documentation (https://caddyserver.com/docs/json/apps/tls/)
// and Automatic HTTPS documentation (https://caddyserver.com/docs/automatic-https).
// ---------------------------------------------------------------------------

/// ACME DNS-01 challenge provider configuration.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaddyDnsProvider {
    /// DNS provider module name (e.g. `"cloudflare"`).
    pub name: String,
    /// API token for DNS provider API authentication.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub api_token: Option<String>,
}

/// DNS challenge settings for ACME issuers.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaddyDnsChallenge {
    /// DNS challenge provider configuration.
    pub provider: CaddyDnsProvider,
}

/// HTTP-01 challenge settings for ACME issuers.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct CaddyHttpChallenge {
    /// Whether the HTTP-01 challenge is disabled.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub disabled: Option<bool>,
}

/// TLS-ALPN-01 challenge settings for ACME issuers.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct CaddyTlsAlpnChallenge {
    /// Whether the TLS-ALPN-01 challenge is disabled.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub disabled: Option<bool>,
}

/// ACME challenge configurations supported by Caddy.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct CaddyAcmeChallenges {
    /// DNS-01 challenge configuration for wildcard certificates and DNS automation.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dns: Option<CaddyDnsChallenge>,
    /// HTTP-01 challenge configuration.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub http: Option<CaddyHttpChallenge>,
    /// TLS-ALPN-01 challenge configuration.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tls_alpn: Option<CaddyTlsAlpnChallenge>,
}

/// ACME issuer specification within Caddy TLS automation.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaddyAcmeIssuer {
    /// Module discriminator (always `"acme"`).
    pub module: String,
    /// Optional directory URL of the ACME CA (e.g. Let's Encrypt / ZeroSSL).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ca: Option<String>,
    /// Account email address for ACME registration and expiry notices.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email: Option<String>,
    /// Challenge configurations.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub challenges: Option<CaddyAcmeChallenges>,
}

impl Default for CaddyAcmeIssuer {
    fn default() -> Self {
        Self {
            module: "acme".to_string(),
            ca: None,
            email: None,
            challenges: None,
        }
    }
}

/// TLS automation policy governing certificate issuance for specific subjects.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct CaddyAutomationPolicy {
    /// Subjects (domains or wildcards e.g. `["*.example.com"]`) to which this policy applies.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub subjects: Option<Vec<String>>,
    /// Ordered list of ACME issuers.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub issuers: Option<Vec<CaddyAcmeIssuer>>,
    /// On-demand TLS flag.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub on_demand: Option<bool>,
}

/// Complete site block payload registered under Caddy HTTP routes.
///
/// Embeds `"@id"` so that it can be addressed, patched, and deleted directly
/// without walking or replacing the overall config tree.
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

/// Builds a site block for a verified custom domain, enforcing the verified-only security rule.
///
/// Returns an error if `is_verified` is `false`.
pub fn build_verified_custom_domain_site_block(
    site_id: &str,
    domain: &str,
    storage_prefix: &str,
    is_verified: bool,
) -> Result<CaddySiteBlock, CaddyError> {
    if !is_verified {
        return Err(CaddyError::SecurityViolation(format!(
            "Security rule violation: custom domain '{domain}' is not verified and cannot be added to Caddy configuration."
        )));
    }

    let clean_domain = domain.trim().to_ascii_lowercase();

    Ok(CaddySiteBlock {
        id: site_id.to_string(),
        r#match: Some(vec![CaddyMatchRule {
            host: Some(vec![clean_domain]),
        }]),
        handle: vec![serde_json::json!({
            "handler": "file_server",
            "root": format!("/var/bloom/web/{storage_prefix}"),
            "index_names": ["index.html"]
        })],
        terminal: Some(true),
    })
}

/// Builds a TLS automation policy for wildcard or custom DNS-01 ACME challenge resolution.
pub fn build_dns_challenge_automation_policy(
    domain: &str,
    cloudflare_api_token: Option<&str>,
    acme_email: Option<&str>,
) -> CaddyAutomationPolicy {
    let clean_domain = domain.trim().to_ascii_lowercase();
    let subjects = if clean_domain.starts_with("*.") {
        vec![clean_domain]
    } else {
        vec![clean_domain.clone(), format!("*.{clean_domain}")]
    };

    let challenges = cloudflare_api_token.map(|token| CaddyAcmeChallenges {
        dns: Some(CaddyDnsChallenge {
            provider: CaddyDnsProvider {
                name: "cloudflare".to_string(),
                api_token: Some(token.to_string()),
            },
        }),
        http: None,
        tls_alpn: None,
    });

    let issuer = CaddyAcmeIssuer {
        module: "acme".to_string(),
        ca: None,
        email: acme_email.map(str::to_string),
        challenges,
    };

    CaddyAutomationPolicy {
        subjects: Some(subjects),
        issuers: Some(vec![issuer]),
        on_demand: None,
    }
}

/// Caddy Admin API client for dynamic route and TLS policy management.
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
    pub fn id_endpoint_url(&self, id: &str) -> String {
        format!("{}/id/{}", self.admin_url, id.trim())
    }

    /// Constructs the scoped URL for addressing a subpath of an `@id` tagged object.
    pub fn id_subpath_endpoint_url(&self, id: &str, path: &str) -> String {
        let clean_path = path.trim().trim_start_matches('/');
        format!("{}/id/{}/{}", self.admin_url, id.trim(), clean_path)
    }

    /// Constructs a config path URL.
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
    /// If the site block is already absent (HTTP 404), this operation succeeds idempotently.
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
        // 404 is treated as a successful no-op for idempotent deletion
        if !response.status().is_success() && status != 404 {
            let body = response.text().await.unwrap_or_default();
            return Err(CaddyError::Api {
                status,
                message: body,
            });
        }

        Ok(())
    }

    /// Adds a TLS automation policy to Caddy configuration.
    pub async fn add_tls_automation_policy(
        &self,
        policy: &CaddyAutomationPolicy,
    ) -> Result<(), CaddyError> {
        let path = format!("{DEFAULT_CADDY_TLS_POLICIES_PATH}/...");
        let url = self.config_endpoint_url(&path);
        let headers = self.build_headers()?;

        let response = self
            .http
            .post(&url)
            .headers(headers)
            .json(policy)
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

    /// Provisions a custom domain route and ACME TLS automation in Caddy.
    ///
    /// # Security Rule
    ///
    /// Validates `is_verified` before touching Caddy. If unverified, immediately returns
    /// `CaddyError::SecurityViolation` without modifying the live reverse proxy configuration.
    pub async fn provision_verified_custom_domain(
        &self,
        domain_public_id: &str,
        domain: &str,
        storage_prefix: &str,
        is_verified: bool,
        cloudflare_api_token: Option<&str>,
        acme_email: Option<&str>,
    ) -> Result<String, CaddyError> {
        if !is_verified {
            return Err(CaddyError::SecurityViolation(format!(
                "Security rule violation: domain '{domain}' is not verified. Unverified domains cannot be added to Caddy."
            )));
        }

        let site_id = caddy_custom_domain_id(domain_public_id);
        let site_block =
            build_verified_custom_domain_site_block(&site_id, domain, storage_prefix, is_verified)?;

        // 1. If wildcard, register DNS-01 ACME automation policy
        if domain.starts_with("*.") || cloudflare_api_token.is_some() {
            let policy =
                build_dns_challenge_automation_policy(domain, cloudflare_api_token, acme_email);
            // Tolerant of policy addition if already exists or path created
            let _ = self.add_tls_automation_policy(&policy).await;
        }

        // 2. Add or update the site block route in Caddy
        match self
            .add_site_block(DEFAULT_CADDY_ROUTES_PATH, &site_block)
            .await
        {
            Ok(()) => Ok(site_id),
            Err(CaddyError::Api { status: 409, .. }) => {
                self.update_site_block(&site_id, &site_block).await?;
                Ok(site_id)
            }
            Err(err) => Err(err),
        }
    }

    /// Inserts a value strictly at a specific path or array index using PUT.
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
