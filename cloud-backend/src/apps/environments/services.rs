//! Business logic, domain rules, and transactional workflows for `environments`.

use chrono::Utc;
use djangors_db::Database;
use rand::Rng;
use std::collections::HashMap;
use uuid::Uuid;

use super::contracts::{
    ApiConfig, BuildConfig, EnvironmentCreateRequest, EnvironmentUpdateRequest,
};
use super::errors::EnvironmentError;
use super::models::Environment;
use super::repositories::{self, AppSummary, OrganizationSummary};

/// Valid build profiles.
pub const VALID_BUILD_PROFILES: &[&str] = &["debug", "profile", "release"];

/// Convert a string into a clean, URL-safe slug.
pub fn slugify(name: &str) -> String {
    crate::apps::common::slug::slugify(name, "env")
}

/// Validate that a build profile is one of `debug`, `profile`, or `release`.
pub fn validate_build_profile(profile: &str) -> Result<(), EnvironmentError> {
    if VALID_BUILD_PROFILES.contains(&profile) {
        Ok(())
    } else {
        Err(EnvironmentError::InvalidBuildProfile)
    }
}

/// Validate `api_config` shape and serialize it to JSON string.
pub fn validate_and_serialize_api_config(config: &ApiConfig) -> Result<String, EnvironmentError> {
    serde_json::to_string(config).map_err(|e| EnvironmentError::InvalidApiConfig(e.to_string()))
}

/// Generate a unique slug for an environment within an app.
pub async fn generate_unique_slug(
    db: &Database,
    app_id: i64,
    base_slug: &str,
) -> Result<String, EnvironmentError> {
    let base = if base_slug.len() > 55 {
        &base_slug[..55]
    } else {
        base_slug
    };

    if !repositories::environment_slug_exists_in_app(db, app_id, base).await? {
        return Ok(base.to_string());
    }

    for counter in 2..1000 {
        let candidate = format!("{base}-{counter}");
        if !repositories::environment_slug_exists_in_app(db, app_id, &candidate).await? {
            return Ok(candidate);
        }
    }

    let random_suffix: String = rand::thread_rng()
        .sample_iter(&rand::distributions::Alphanumeric)
        .take(6)
        .map(char::from)
        .collect();
    Ok(format!("{base}-{}", random_suffix.to_lowercase()))
}

/// Emits an event to the events log.
///
/// Delegates to the `events` app's public service interface, which swallows and logs any
/// recording failure so that emitting an event never fails this app's own write.
pub async fn emit_event(
    db: &Database,
    event_type: &str,
    organization_id: Option<i64>,
    project_id: Option<i64>,
    app_id: Option<i64>,
    actor_id: Option<i64>,
    payload: serde_json::Value,
) {
    crate::apps::events::emit(
        db,
        event_type,
        organization_id,
        project_id,
        app_id,
        actor_id,
        payload,
    )
    .await;
}

/// Create a new `Environment` entity scoped to an app and organization.
pub async fn create_environment(
    db: &Database,
    organization_id: i64,
    actor_user_id: Option<i64>,
    req: EnvironmentCreateRequest,
) -> Result<(Environment, AppSummary, OrganizationSummary), EnvironmentError> {
    let trimmed_name = req.name.trim();
    if trimmed_name.is_empty() {
        return Err(EnvironmentError::ValidationError(
            "Environment name cannot be empty.".to_string(),
        ));
    }
    if trimmed_name.len() > 255 {
        return Err(EnvironmentError::ValidationError(
            "Environment name cannot exceed 255 characters.".to_string(),
        ));
    }

    // 1. Resolve app by public UUID and ensure it belongs to the active organization
    let app = repositories::app_by_public_id_and_org(db, &req.app_id, organization_id)
        .await?
        .ok_or(EnvironmentError::AppNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(EnvironmentError::OrganizationNotFound)?;

    // 2. Resolve & validate slug uniqueness per app
    let raw_slug = req.slug.trim();
    let target_slug = if raw_slug.is_empty() {
        let base_slug = slugify(trimmed_name);
        generate_unique_slug(db, app.id, &base_slug).await?
    } else {
        let clean_slug = slugify(raw_slug);
        if repositories::environment_slug_exists_in_app(db, app.id, &clean_slug).await? {
            return Err(EnvironmentError::SlugTaken);
        }
        clean_slug
    };

    // 3. Validate api_config JSON shape
    let api_config_json = validate_and_serialize_api_config(&req.api_config)?;

    // 4. Validate build profile
    let build_profile = req
        .build_profile
        .as_deref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .unwrap_or("release");
    validate_build_profile(build_profile)?;

    let flutter_version = req
        .flutter_version
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty());

    let dart_version = req
        .dart_version
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty());

    let bloom_version = req
        .bloom_version
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty());

    let flavor = req
        .flavor
        .map(|f| f.trim().to_string())
        .filter(|f| !f.is_empty());

    let now = Utc::now();
    let env = Environment {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        app_id: app.id,
        organization_id,
        name: trimmed_name.to_string(),
        slug: target_slug,
        api_config: api_config_json,
        build_profile: build_profile.to_string(),
        flutter_version,
        dart_version,
        bloom_version,
        flavor,
        created_at: now,
        updated_at: now,
    };

    // 5. Insert
    let saved_env = repositories::insert_environment(db, env).await?;

    // 6. Emit environment.created event
    emit_event(
        db,
        "environment.created",
        Some(organization_id),
        None,
        Some(app.id),
        actor_user_id,
        serde_json::json!({
            "environment_id": saved_env.public_id,
            "app_id": app.public_id,
        }),
    )
    .await;

    Ok((saved_env, app, org))
}

/// Retrieve an environment by its public UUID within an organization.
pub async fn get_environment(
    db: &Database,
    organization_id: i64,
    env_public_id: &str,
) -> Result<(Environment, AppSummary, OrganizationSummary), EnvironmentError> {
    let env = repositories::environment_by_public_id_and_org(db, env_public_id, organization_id)
        .await?
        .ok_or(EnvironmentError::EnvironmentNotFound)?;

    let app = repositories::app_summary_by_id(db, env.app_id)
        .await?
        .ok_or(EnvironmentError::AppNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(EnvironmentError::OrganizationNotFound)?;

    Ok((env, app, org))
}

/// List all environments in an organization (or optionally filtered by app).
pub async fn list_environments(
    db: &Database,
    organization_id: i64,
    app_public_id: Option<&str>,
) -> Result<Vec<(Environment, AppSummary, OrganizationSummary)>, EnvironmentError> {
    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(EnvironmentError::OrganizationNotFound)?;

    let envs = if let Some(app_pub_id) = app_public_id {
        let app = repositories::app_by_public_id_and_org(db, app_pub_id, organization_id)
            .await?
            .ok_or(EnvironmentError::AppNotFound)?;
        repositories::environments_for_app(db, app.id, organization_id).await?
    } else {
        repositories::environments_for_organization(db, organization_id).await?
    };

    let mut results = Vec::with_capacity(envs.len());
    for env in envs {
        if let Some(app) = repositories::app_summary_by_id(db, env.app_id).await? {
            results.push((env, app, org.clone()));
        }
    }

    Ok(results)
}

/// Partially update an `Environment`.
pub async fn update_environment(
    db: &Database,
    organization_id: i64,
    actor_user_id: Option<i64>,
    env_public_id: &str,
    req: EnvironmentUpdateRequest,
) -> Result<(Environment, AppSummary, OrganizationSummary), EnvironmentError> {
    let (mut env, app, org) = get_environment(db, organization_id, env_public_id).await?;

    if let Some(name) = req.name {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(EnvironmentError::ValidationError(
                "Environment name cannot be empty.".to_string(),
            ));
        }
        if trimmed.len() > 255 {
            return Err(EnvironmentError::ValidationError(
                "Environment name cannot exceed 255 characters.".to_string(),
            ));
        }
        env.name = trimmed.to_string();
    }

    if let Some(api_config) = req.api_config {
        let api_config_json = validate_and_serialize_api_config(&api_config)?;
        env.api_config = api_config_json;
    }

    if let Some(profile) = req.build_profile {
        let trimmed = profile.trim();
        validate_build_profile(trimmed)?;
        env.build_profile = trimmed.to_string();
    }

    if let Some(flutter_version) = req.flutter_version {
        let trimmed = flutter_version.trim();
        if trimmed.is_empty() {
            env.flutter_version = None;
        } else {
            if trimmed.len() > 64 {
                return Err(EnvironmentError::ValidationError(
                    "Flutter version cannot exceed 64 characters.".to_string(),
                ));
            }
            env.flutter_version = Some(trimmed.to_string());
        }
    }

    if let Some(dart_version) = req.dart_version {
        let trimmed = dart_version.trim();
        if trimmed.is_empty() {
            env.dart_version = None;
        } else {
            if trimmed.len() > 64 {
                return Err(EnvironmentError::ValidationError(
                    "Dart version cannot exceed 64 characters.".to_string(),
                ));
            }
            env.dart_version = Some(trimmed.to_string());
        }
    }

    if let Some(bloom_version) = req.bloom_version {
        let trimmed = bloom_version.trim();
        if trimmed.is_empty() {
            env.bloom_version = None;
        } else {
            if trimmed.len() > 64 {
                return Err(EnvironmentError::ValidationError(
                    "Bloom version cannot exceed 64 characters.".to_string(),
                ));
            }
            env.bloom_version = Some(trimmed.to_string());
        }
    }

    if let Some(flavor) = req.flavor {
        let trimmed = flavor.trim();
        if trimmed.is_empty() {
            env.flavor = None;
        } else {
            if trimmed.len() > 64 {
                return Err(EnvironmentError::ValidationError(
                    "Flavor cannot exceed 64 characters.".to_string(),
                ));
            }
            env.flavor = Some(trimmed.to_string());
        }
    }

    env.updated_at = Utc::now();
    repositories::update_environment(db, &env).await?;

    // Emit environment.updated event
    emit_event(
        db,
        "environment.updated",
        Some(organization_id),
        None,
        Some(app.id),
        actor_user_id,
        serde_json::json!({
            "environment_id": env.public_id,
            "app_id": app.public_id,
        }),
    )
    .await;

    Ok((env, app, org))
}

/// Delete an `Environment` record.
pub async fn delete_environment(
    db: &Database,
    organization_id: i64,
    actor_user_id: Option<i64>,
    env_public_id: &str,
) -> Result<(), EnvironmentError> {
    let (env, app, _) = get_environment(db, organization_id, env_public_id).await?;

    repositories::delete_environment_by_id(db, env.id).await?;

    // Emit environment.deleted event
    emit_event(
        db,
        "environment.deleted",
        Some(organization_id),
        None,
        Some(app.id),
        actor_user_id,
        serde_json::json!({
            "environment_id": env.public_id,
            "app_id": app.public_id,
        }),
    )
    .await;

    Ok(())
}

/// Merges environment defaults with secrets to produce the full effective configuration that a build worker receives.
/// This is computed dynamically at worker job execution time, not stored.
pub fn get_effective_build_config(
    env: &Environment,
    secrets: HashMap<String, String>,
) -> BuildConfig {
    let parsed_config: ApiConfig = serde_json::from_str(&env.api_config).unwrap_or_default();

    let mut merged_env_vars = HashMap::new();
    for env_var in parsed_config.env_vars {
        merged_env_vars.insert(env_var.key, env_var.value);
    }
    // Secrets override or augment declared non-secret env vars
    for (secret_key, secret_val) in secrets {
        merged_env_vars.insert(secret_key, secret_val);
    }

    let mut feature_flags = HashMap::new();
    for flag in parsed_config.feature_flags {
        feature_flags.insert(flag.key, flag.enabled);
    }

    BuildConfig {
        env_vars: merged_env_vars,
        feature_flags,
        build_profile: env.build_profile.clone(),
        flutter_version: env.flutter_version.clone(),
        dart_version: env.dart_version.clone(),
        bloom_version: env.bloom_version.clone(),
        flavor: env.flavor.clone(),
    }
}
