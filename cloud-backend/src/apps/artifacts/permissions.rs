//! Role-based permissions, worker job-token authentication, and authorization helpers for `artifacts`.

use std::fmt;

use chrono::Utc;
use djangors_core::Request;

pub use crate::apps::accounts::permissions::CurrentOrganizationId;
pub use crate::apps::organizations::permissions::{
    CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};
use crate::infra::crypto::Crypto;

use super::errors::ArtifactError;

/// Default validity lifetime for a minted worker job token (4 hours = 14400 seconds).
///
/// Build workers can execute for up to several hours across multiple stages.
pub const DEFAULT_JOB_TOKEN_TTL_SECS: i64 = 14400;

/// Parsed, verified claims extracted from a scoped worker job token.
///
/// Implements a custom [`fmt::Debug`] to ensure internal secrets or sensitive fields
/// are never leaked into logs.
#[derive(Clone, PartialEq, Eq)]
pub struct JobTokenClaims {
    /// Public UUID of the build for which this token is valid.
    pub build_id: String,
    /// Public UUID of the organization owning the build.
    pub organization_id: String,
    /// Unix timestamp (seconds) when the token was issued.
    pub issued_at: i64,
    /// Unix timestamp (seconds) after which the token is invalid.
    pub expires_at: i64,
}

impl fmt::Debug for JobTokenClaims {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("JobTokenClaims")
            .field("build_id", &self.build_id)
            .field("organization_id", &self.organization_id)
            .field("issued_at", &self.issued_at)
            .field("expires_at", &self.expires_at)
            .finish()
    }
}

/// A scoped, expiring worker job token.
///
/// Wraps the signed token string and customizes [`fmt::Debug`] and [`fmt::Display`]
/// to strictly redact the raw token representation from any logs or debug dumps.
#[derive(Clone, PartialEq, Eq)]
pub struct JobToken {
    raw: String,
    claims: JobTokenClaims,
}

impl JobToken {
    /// Returns a reference to the verified token claims.
    pub fn claims(&self) -> &JobTokenClaims {
        &self.claims
    }

    /// Exposes the raw signed token string for setting in request headers.
    ///
    /// The raw token is never printed in [`fmt::Debug`] or [`fmt::Display`].
    pub fn as_str(&self) -> &str {
        &self.raw
    }
}

impl fmt::Debug for JobToken {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("JobToken")
            .field("raw", &"[REDACTED]")
            .field("claims", &self.claims)
            .finish()
    }
}

impl fmt::Display for JobToken {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[REDACTED_JOB_TOKEN]")
    }
}

/// Retrieves the signing key used for minting and verifying worker job tokens.
///
/// Priority:
/// 1. `BLOOM_JOB_TOKEN_SECRET` / `JOB_TOKEN_SECRET`
/// 2. `BLOOM_ENCRYPTION_KEY` / `ENCRYPTION_KEY`
pub fn get_job_token_signing_key() -> Result<Vec<u8>, ArtifactError> {
    if let Ok(key) =
        std::env::var("BLOOM_JOB_TOKEN_SECRET").or_else(|_| std::env::var("JOB_TOKEN_SECRET"))
    {
        if !key.trim().is_empty() {
            return Ok(key.into_bytes());
        }
    }

    if let Ok(key) =
        std::env::var("BLOOM_ENCRYPTION_KEY").or_else(|_| std::env::var("ENCRYPTION_KEY"))
    {
        if !key.trim().is_empty() {
            return Ok(key.into_bytes());
        }
    }

    Err(ArtifactError::InvalidJobToken)
}

/// Mints a scoped, expiring, HMAC-SHA256 signed worker job token for a build.
///
/// The token payload is `{build_id}:{organization_id}:{issued_at}:{expires_at}` and is
/// signed using [`Crypto::hmac_sha256_hex`].
pub fn mint_job_token(
    build_public_id: &str,
    org_public_id: &str,
    ttl_secs: i64,
    signing_key: &[u8],
) -> JobToken {
    let now = Utc::now().timestamp();
    let expires_at = now.saturating_add(ttl_secs);
    let payload = format!("{build_public_id}:{org_public_id}:{now}:{expires_at}");
    let signature = Crypto::hmac_sha256_hex(signing_key, payload.as_bytes());
    let raw = format!("{payload}:{signature}");

    JobToken {
        raw,
        claims: JobTokenClaims {
            build_id: build_public_id.to_string(),
            organization_id: org_public_id.to_string(),
            issued_at: now,
            expires_at,
        },
    }
}

/// Verifies a scoped worker job token against a specific build and organization.
///
/// Verification is strictly FAIL-CLOSED:
/// - Any malformed, missing, tampered, or unparseable token is rejected.
/// - Any token where `now > expires_at` is rejected.
/// - Any token whose `build_id` or `organization_id` does not match the target scope is rejected.
/// - Signature comparison is performed in constant time via [`Crypto::constant_time_eq_str`].
pub fn verify_job_token(
    token_str: &str,
    expected_build_id: Option<&str>,
    expected_org_id: Option<&str>,
    signing_key: &[u8],
) -> Result<JobTokenClaims, ArtifactError> {
    let parts: Vec<&str> = token_str.split(':').collect();
    if parts.len() != 5 {
        return Err(ArtifactError::InvalidJobToken);
    }

    let build_id = parts[0];
    let organization_id = parts[1];
    let issued_at_str = parts[2];
    let expires_at_str = parts[3];
    let provided_sig = parts[4];

    if build_id.is_empty() || organization_id.is_empty() {
        return Err(ArtifactError::InvalidJobToken);
    }

    let issued_at = issued_at_str
        .parse::<i64>()
        .map_err(|_| ArtifactError::InvalidJobToken)?;
    let expires_at = expires_at_str
        .parse::<i64>()
        .map_err(|_| ArtifactError::InvalidJobToken)?;

    // 1. Verify constant-time HMAC signature over payload
    let payload = format!("{build_id}:{organization_id}:{issued_at}:{expires_at}");
    let expected_sig = Crypto::hmac_sha256_hex(signing_key, payload.as_bytes());

    if !Crypto::constant_time_eq_str(provided_sig, &expected_sig) {
        return Err(ArtifactError::InvalidJobToken);
    }

    // 2. Verify expiration (fail-closed if expired)
    let now = Utc::now().timestamp();
    if now > expires_at {
        return Err(ArtifactError::InvalidJobToken);
    }

    // 3. Verify scope matching when expectations are provided
    if let Some(expected_build) = expected_build_id {
        if !Crypto::constant_time_eq_str(build_id, expected_build) {
            return Err(ArtifactError::InvalidJobToken);
        }
    }

    if let Some(expected_org) = expected_org_id {
        if !Crypto::constant_time_eq_str(organization_id, expected_org) {
            return Err(ArtifactError::InvalidJobToken);
        }
    }

    Ok(JobTokenClaims {
        build_id: build_id.to_string(),
        organization_id: organization_id.to_string(),
        issued_at,
        expires_at,
    })
}

/// Enforce that the caller is an internal worker presenting a valid scoped job token.
///
/// Parses `X-Bloom-Job-Token` from request headers, extracts the token, and validates
/// the HMAC signature and expiration.
pub fn require_job_token(req: &Request) -> Result<JobTokenClaims, ArtifactError> {
    let presented = req
        .header("x-bloom-job-token")
        .and_then(|v| v.to_str().ok())
        .ok_or(ArtifactError::InvalidJobToken)?;

    let signing_key = get_job_token_signing_key()?;
    verify_job_token(presented, None, None, &signing_key)
}

/// Enforce that the caller is an internal worker presenting a valid job token scoped
/// to a specific build and organization.
pub fn require_scoped_job_token(
    req: &Request,
    expected_build_id: &str,
    expected_org_id: &str,
) -> Result<JobTokenClaims, ArtifactError> {
    let presented = req
        .header("x-bloom-job-token")
        .and_then(|v| v.to_str().ok())
        .ok_or(ArtifactError::InvalidJobToken)?;

    let signing_key = get_job_token_signing_key()?;
    verify_job_token(
        presented,
        Some(expected_build_id),
        Some(expected_org_id),
        &signing_key,
    )
}
