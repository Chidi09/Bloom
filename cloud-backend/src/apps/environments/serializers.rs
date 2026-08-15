//! Serialization adapters and representation converters for `environments`.

use super::contracts::{ApiConfig, EnvironmentResponse};
use super::models::Environment;

/// Deserializes the raw JSON string `api_config` into a strongly-typed [`ApiConfig`].
/// Falls back to empty `ApiConfig` if parsing fails.
pub fn deserialize_api_config(raw_json: &str) -> ApiConfig {
    serde_json::from_str(raw_json).unwrap_or_default()
}

/// Serializes an [`Environment`] model instance into an [`EnvironmentResponse`] wire contract.
///
/// `app_public_id` and `organization_public_id` are the external UUID strings
/// corresponding to the foreign keys on the model.
pub fn serialize_environment(
    env: &Environment,
    app_public_id: &str,
    organization_public_id: &str,
) -> EnvironmentResponse {
    let api_config = deserialize_api_config(&env.api_config);

    EnvironmentResponse {
        id: env.public_id.clone(),
        app_id: app_public_id.to_string(),
        organization_id: organization_public_id.to_string(),
        name: env.name.clone(),
        slug: env.slug.clone(),
        api_config,
        build_profile: env.build_profile.clone(),
        flutter_version: env.flutter_version.clone(),
        dart_version: env.dart_version.clone(),
        bloom_version: env.bloom_version.clone(),
        flavor: env.flavor.clone(),
        created_at: env.created_at.to_rfc3339(),
        updated_at: env.updated_at.to_rfc3339(),
    }
}
