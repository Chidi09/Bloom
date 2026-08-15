//! HTTP contracts (request and response DTOs) and typed configuration for `environments`.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Non-secret environment variable entry.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EnvVar {
    /// Environment variable key name.
    pub key: String,
    /// Declared non-secret value.
    pub value: String,
}

/// Feature flag configuration entry.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FeatureFlag {
    /// Feature flag key name.
    pub key: String,
    /// Whether the flag is enabled.
    pub enabled: bool,
}

/// Typed structure representing the `api_config` JSON document.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApiConfig {
    /// Non-secret environment variables.
    #[serde(default)]
    pub env_vars: Vec<EnvVar>,
    /// Feature flags.
    #[serde(default)]
    pub feature_flags: Vec<FeatureFlag>,
}

/// Request payload to create a new `Environment` within an app.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct EnvironmentCreateRequest {
    /// Public UUID of the parent application.
    pub app_id: String,
    /// Human-readable environment name (e.g. "Production").
    pub name: String,
    /// URL-safe slug unique per app (e.g. "production").
    pub slug: String,
    /// Typed non-secret environment configuration and feature flags.
    pub api_config: ApiConfig,
    /// Optional build profile (`debug`, `profile`, `release`), defaults to `release`.
    #[serde(default)]
    pub build_profile: Option<String>,
    /// Optional pinned Flutter version.
    #[serde(default)]
    pub flutter_version: Option<String>,
    /// Optional pinned Dart version.
    #[serde(default)]
    pub dart_version: Option<String>,
    /// Optional pinned Bloom CLI version.
    #[serde(default)]
    pub bloom_version: Option<String>,
    /// Optional build flavor.
    #[serde(default)]
    pub flavor: Option<String>,
}

/// Request payload to partially update an existing `Environment`.
#[derive(Debug, Clone, Default, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct EnvironmentUpdateRequest {
    /// Optional updated environment name.
    pub name: Option<String>,
    /// Optional updated typed environment configuration and feature flags.
    pub api_config: Option<ApiConfig>,
    /// Optional updated build profile (`debug`, `profile`, `release`).
    pub build_profile: Option<String>,
    /// Optional updated pinned Flutter version.
    pub flutter_version: Option<String>,
    /// Optional updated pinned Dart version.
    pub dart_version: Option<String>,
    /// Optional updated pinned Bloom CLI version.
    pub bloom_version: Option<String>,
    /// Optional updated build flavor.
    pub flavor: Option<String>,
}

/// Wire representation of an `Environment`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct EnvironmentResponse {
    /// Public UUID identifier of the environment.
    pub id: String,
    /// Public UUID identifier of the parent application.
    pub app_id: String,
    /// Public UUID identifier of the owning organization.
    pub organization_id: String,
    /// Human-readable environment name.
    pub name: String,
    /// Unique URL-safe slug within the app.
    pub slug: String,
    /// Typed non-secret environment configuration and feature flags.
    pub api_config: ApiConfig,
    /// Build profile (`debug`, `profile`, `release`).
    pub build_profile: String,
    /// Optional pinned Flutter version.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub flutter_version: Option<String>,
    /// Optional pinned Dart version.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dart_version: Option<String>,
    /// Optional pinned Bloom CLI version.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bloom_version: Option<String>,
    /// Optional build flavor.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub flavor: Option<String>,
    /// ISO 8601 creation timestamp.
    pub created_at: String,
    /// ISO 8601 last update timestamp.
    pub updated_at: String,
}

/// Merged build configuration computed at worker job time (merges environment defaults + decrypted secrets).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BuildConfig {
    /// Resolved environment variables (env_vars merged with decrypted secrets).
    pub env_vars: HashMap<String, String>,
    /// Resolved feature flags.
    pub feature_flags: HashMap<String, bool>,
    /// Build profile to use (`debug`, `profile`, `release`).
    pub build_profile: String,
    /// Flutter SDK version pinned or default.
    pub flutter_version: Option<String>,
    /// Dart SDK version pinned or default.
    pub dart_version: Option<String>,
    /// Bloom CLI version pinned or default.
    pub bloom_version: Option<String>,
    /// Build flavor if configured.
    pub flavor: Option<String>,
}
