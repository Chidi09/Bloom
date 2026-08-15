//! Business logic, domain rules, and transactional workflows for `webhosting`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{CreateCustomDomainRequest, DeployWebRequest};
use super::errors::WebHostingError;
use super::models::{CustomDomain, WebDeployment};
use super::permissions::OrganizationRole;
use super::repositories::{self};
use crate::infra::storage::ObjectStorage;

/// Valid deployment target types.
pub const VALID_TARGETS: &[&str] = &["preview", "production"];

/// Valid deployment lifecycle statuses.
pub const VALID_DEPLOYMENT_STATUSES: &[&str] = &["deploying", "live", "failed", "rolled_back"];

/// Valid custom domain certificate statuses.
pub const VALID_CERTIFICATE_STATUSES: &[&str] = &["pending", "issued", "expired"];

/// Default apex domain when `CloudflareSettings.apex_domain` is unconfigured.
pub const DEFAULT_APEX_DOMAIN: &str = "bloomcloud.dev";

/// Detailed web deployment with resolved related public UUIDs for wire serialization.
#[derive(Debug, Clone)]
pub struct WebDeploymentDetail {
    /// The underlying web deployment record.
    pub deployment: WebDeployment,
    /// External public UUID of the parent app.
    pub app_public_id: String,
    /// External public UUID of the target environment.
    pub environment_public_id: String,
    /// Optional external public UUID of the associated release.
    pub release_public_id: Option<String>,
    /// Public identifier string of the deploying user.
    pub deployed_by_public_id: String,
}

/// Detailed custom domain with resolved parent app public UUID for wire serialization.
#[derive(Debug, Clone)]
pub struct CustomDomainDetail {
    /// The underlying custom domain record.
    pub domain: CustomDomain,
    /// External public UUID of the parent app.
    pub app_public_id: String,
}

/// Returns `true` when `from -> to` is a legal deployment status transition.
///
/// Status lifecycle:
/// - `deploying` can transition to `live` (on successful worker deploy) or `failed`.
/// - `live` can transition to `rolled_back` (when a rollback restores the previous live deployment).
/// - Terminal states (`failed`, `rolled_back`) are absorbing.
pub fn can_transition(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("deploying", "live") | ("deploying", "failed") | ("live", "rolled_back")
    )
}

/// Sanitizes a Git branch name for use as a subdomain component.
pub fn sanitize_branch_slug(branch: &str) -> String {
    // Runs of separators collapse to a single dash, matching `slugify` in
    // src/apps/apps/services.rs. This value becomes a DNS label in the preview hostname,
    // so `feature//x` must not produce `feature--x`.
    let mut sanitized = String::with_capacity(branch.len());
    let mut last_was_dash = true;
    for c in branch.chars() {
        if c.is_ascii_alphanumeric() {
            sanitized.push(c.to_ascii_lowercase());
            last_was_dash = false;
        } else if !last_was_dash {
            sanitized.push('-');
            last_was_dash = true;
        }
    }

    let trimmed = sanitized.trim_matches('-');
    if trimmed.is_empty() {
        "preview".to_string()
    } else {
        trimmed.to_string()
    }
}

/// Constructs a preview URL under the configured Cloudflare apex domain.
///
/// Pattern: `https://{branch}-{app_slug}-{project_slug}.{apex_domain}`
/// Defaults to `bloomcloud.dev` if no apex domain is configured.
pub fn build_preview_url(
    apex_domain: Option<&str>,
    branch: &str,
    app_slug: &str,
    project_slug: &str,
) -> String {
    let apex = apex_domain
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .unwrap_or(DEFAULT_APEX_DOMAIN);

    let clean_branch = sanitize_branch_slug(branch);
    let clean_app = app_slug.trim().to_ascii_lowercase();
    let clean_project = project_slug.trim().to_ascii_lowercase();

    format!("https://{clean_branch}-{clean_app}-{clean_project}.{apex}")
}

/// Constructs a production URL under the configured Cloudflare apex domain.
///
/// Pattern: `https://{app_slug}-{project_slug}.{apex_domain}`
/// Defaults to `bloomcloud.dev` if no apex domain is configured.
pub fn build_production_url(
    apex_domain: Option<&str>,
    app_slug: &str,
    project_slug: &str,
) -> String {
    let apex = apex_domain
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .unwrap_or(DEFAULT_APEX_DOMAIN);

    let clean_app = app_slug.trim().to_ascii_lowercase();
    let clean_project = project_slug.trim().to_ascii_lowercase();

    format!("https://{clean_app}-{clean_project}.{apex}")
}

/// Constructs the canonical object-storage path prefix for a web deployment.
///
/// Hierarchy:
/// `orgs/{org_public_id}/projects/{project_public_id}/apps/{app_public_id}/web/{deployment_public_id}`
pub fn build_web_storage_prefix(
    org_public_id: &str,
    project_public_id: &str,
    app_public_id: &str,
    deployment_public_id: &str,
) -> String {
    format!(
        "orgs/{org_public_id}/projects/{project_public_id}/apps/{app_public_id}/web/{deployment_public_id}"
    )
}

/// Validates that a target is one of `preview` or `production`.
pub fn validate_target(target: &str) -> Result<(), WebHostingError> {
    if VALID_TARGETS.contains(&target) {
        Ok(())
    } else {
        Err(WebHostingError::InvalidTarget)
    }
}

/// Validates a custom domain string format.
pub fn validate_domain(domain: &str) -> Result<String, WebHostingError> {
    let trimmed = domain.trim().to_ascii_lowercase();
    if trimmed.is_empty() || trimmed.len() > 255 {
        return Err(WebHostingError::InvalidDomain);
    }
    if trimmed.starts_with("http://") || trimmed.starts_with("https://") || trimmed.contains('/') {
        return Err(WebHostingError::InvalidDomain);
    }
    if !trimmed.contains('.') || trimmed.starts_with('.') || trimmed.ends_with('.') {
        return Err(WebHostingError::InvalidDomain);
    }
    let valid_chars = trimmed
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-');
    if !valid_chars {
        return Err(WebHostingError::InvalidDomain);
    }
    Ok(trimmed)
}

/// Emits an event to the events log.
///
/// Delegates to the `events` app's public service interface.
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

/// Initiates a new Flutter Web deployment.
///
/// # Permissions & Business Rules:
/// 1. `target = "production"` requires caller role of `ReleaseManager` or higher.
/// 2. `target = "preview"` requires caller role of `Developer` or higher.
/// 3. Resolves artifact and environment, verifying both belong to the app and organization.
/// 4. Verifies artifact kind is `"web_bundle"`.
/// 5. Generates the deployment URL and canonical storage prefix.
/// 6. Inserts the deployment with status `deploying`, transitions to `live`.
/// 7. Emits `webhosting.deployed`.
pub async fn deploy_web(
    db: &Database,
    _storage: &dyn ObjectStorage,
    organization_id: i64,
    user_id: i64,
    user_role: OrganizationRole,
    apex_domain: Option<&str>,
    req: DeployWebRequest,
) -> Result<WebDeploymentDetail, WebHostingError> {
    let target = req.target.trim().to_string();
    validate_target(&target)?;

    // Role check: production requires Release Manager or above (Phase 4 exit gate).
    if target == "production" && user_role < OrganizationRole::ReleaseManager {
        return Err(WebHostingError::Forbidden);
    }
    if target == "preview" && user_role < OrganizationRole::Developer {
        return Err(WebHostingError::Forbidden);
    }

    // 1. Resolve organization, app, project, and environment.
    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(WebHostingError::OrganizationNotFound)?;

    let app = repositories::app_summary_by_public_id_and_org(db, &req.app_id, organization_id)
        .await?
        .ok_or(WebHostingError::AppNotFound)?;

    let project = repositories::project_summary_by_id(db, app.project_id)
        .await?
        .ok_or(WebHostingError::ProjectNotFound)?;

    let env = repositories::environment_summary_by_public_id_and_org(
        db,
        &req.environment_id,
        organization_id,
    )
    .await?
    .ok_or(WebHostingError::EnvironmentNotFound)?;

    if env.app_id != app.id {
        return Err(WebHostingError::EnvironmentNotFound);
    }

    // 2. Resolve artifact and verify kind.
    let artifact =
        repositories::artifact_summary_by_public_id_and_org(db, &req.artifact_id, organization_id)
            .await?
            .ok_or(WebHostingError::ArtifactNotFound)?;

    if artifact.kind != "web_bundle" {
        return Err(WebHostingError::InvalidArtifactKind);
    }

    // 3. Resolve optional release.
    let release = if let Some(ref rel_id) = req.release_id {
        let r = repositories::release_summary_by_public_id_and_org(db, rel_id, organization_id)
            .await?
            .ok_or(WebHostingError::ReleaseNotFound)?;
        Some(r)
    } else {
        None
    };

    // 4. Generate URL and canonical storage prefix.
    let deployment_public_id = Uuid::new_v4().to_string();
    let branch = req
        .git_branch
        .as_deref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .unwrap_or(&app.default_branch);

    let deployed_url = match target.as_str() {
        "preview" => build_preview_url(apex_domain, branch, &app.slug, &project.slug),
        "production" => build_production_url(apex_domain, &app.slug, &project.slug),
        _ => return Err(WebHostingError::InvalidTarget),
    };

    let storage_prefix = build_web_storage_prefix(
        &org.public_id,
        &project.public_id,
        &app.public_id,
        &deployment_public_id,
    );

    // 5. Serialize metadata.
    let metadata_json = match req.metadata {
        Some(val) => serde_json::to_string(&val)
            .map_err(|e| WebHostingError::InvalidMetadata(e.to_string()))?,
        None => "{}".to_string(),
    };

    // 6. Insert WebDeployment record.
    let now = Utc::now();
    let deployment = WebDeployment {
        id: 0,
        public_id: deployment_public_id,
        app_id: ForeignKey::new(app.id),
        organization_id,
        environment_id: ForeignKey::new(env.id),
        artifact_id: ForeignKey::new(artifact.id),
        release_id: release.as_ref().map(|r| r.id),
        target: target.clone(),
        url: deployed_url.clone(),
        storage_prefix,
        status: "deploying".to_string(),
        metadata: metadata_json,
        deployed_by_id: user_id,
        created_at: now,
    };

    let mut saved = repositories::insert_deployment(db, deployment).await?;

    // 7. Transition to `live` upon deploy completion.
    // CDN invalidation and Caddy site-block registration are performed by the deploy
    // worker (src/workers/deploy.rs), not here: both are outbound calls to third-party
    // control APIs and must not block an HTTP request handler. The worker purges
    // `storage_prefix` via crate::infra::cdn::CdnClient::purge_prefixes and registers the
    // site via crate::infra::caddy::CaddyClient::add_site_block.
    if can_transition(&saved.status, "live") {
        saved.status = "live".to_string();
        repositories::update_deployment(db, &saved).await?;
    }

    // 8. Emit `webhosting.deployed` event.
    emit_event(
        db,
        "webhosting.deployed",
        Some(organization_id),
        Some(app.project_id),
        Some(app.id),
        Some(user_id),
        serde_json::json!({
            "deployment_id": saved.public_id,
            "url": saved.url,
        }),
    )
    .await;

    Ok(WebDeploymentDetail {
        deployment: saved,
        app_public_id: app.public_id,
        environment_public_id: env.public_id,
        release_public_id: release.map(|r| r.public_id),
        deployed_by_public_id: user_id.to_string(),
    })
}

/// Rollback a web deployment to the previous live deployment for that app and target.
///
/// # Business Rules:
/// 1. Production rollbacks require `ReleaseManager` role or higher.
/// 2. Restores the PREVIOUS successful deployment for the app+target.
/// 3. Expressed as a state transition over existing rows: current becomes `rolled_back`, previous becomes `live`.
/// 4. Emits `webhosting.rolled_back` with `{"deployment_id", "previous_deployment_id"}`.
pub async fn rollback_web_deployment(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    user_role: OrganizationRole,
    deployment_public_id: &str,
) -> Result<WebDeploymentDetail, WebHostingError> {
    let mut current =
        repositories::deployment_by_public_id_and_org(db, deployment_public_id, organization_id)
            .await?
            .ok_or(WebHostingError::DeploymentNotFound)?;

    if current.target == "production" && user_role < OrganizationRole::ReleaseManager {
        return Err(WebHostingError::Forbidden);
    }
    if current.target == "preview" && user_role < OrganizationRole::Developer {
        return Err(WebHostingError::Forbidden);
    }

    if !can_transition(&current.status, "rolled_back") {
        return Err(WebHostingError::InvalidStatus);
    }

    let mut previous = repositories::previous_deployment_for_app_and_target(
        db,
        current.app_id.id,
        organization_id,
        &current.target,
        current.id,
    )
    .await?
    .ok_or(WebHostingError::NoPreviousDeployment)?;

    // State transition over existing deployment rows.
    current.status = "rolled_back".to_string();
    repositories::update_deployment(db, &current).await?;

    previous.status = "live".to_string();
    repositories::update_deployment(db, &previous).await?;

    // CDN invalidation and Caddy site-block registration are performed by the deploy
    // worker (src/workers/deploy.rs), not here: both are outbound calls to third-party
    // control APIs and must not block an HTTP request handler. The worker purges
    // `storage_prefix` via crate::infra::cdn::CdnClient::purge_prefixes and registers the
    // site via crate::infra::caddy::CaddyClient::add_site_block.

    let app = repositories::app_summary_by_id(db, current.app_id.id)
        .await?
        .ok_or(WebHostingError::AppNotFound)?;

    let env = repositories::environment_summary_by_id(db, current.environment_id.id)
        .await?
        .ok_or(WebHostingError::EnvironmentNotFound)?;

    let release_public_id = match current.release_id {
        Some(ref rel) => {
            // Forward-declared stub lookup
            repositories::release_summary_by_id(db, *rel)
                .await?
                .map(|r| r.public_id)
        }
        None => None,
    };

    // Emit `webhosting.rolled_back` event per events.md.
    emit_event(
        db,
        "webhosting.rolled_back",
        Some(organization_id),
        Some(app.project_id),
        Some(app.id),
        Some(user_id),
        serde_json::json!({
            "deployment_id": current.public_id,
            "previous_deployment_id": previous.public_id,
        }),
    )
    .await;

    Ok(WebDeploymentDetail {
        deployment: current,
        app_public_id: app.public_id,
        environment_public_id: env.public_id,
        release_public_id,
        deployed_by_public_id: user_id.to_string(),
    })
}

/// Retrieve a web deployment by its public UUID within an organization.
pub async fn get_web_deployment(
    db: &Database,
    organization_id: i64,
    deployment_public_id: &str,
) -> Result<WebDeploymentDetail, WebHostingError> {
    let deployment =
        repositories::deployment_by_public_id_and_org(db, deployment_public_id, organization_id)
            .await?
            .ok_or(WebHostingError::DeploymentNotFound)?;

    let app = repositories::app_summary_by_id(db, deployment.app_id.id)
        .await?
        .ok_or(WebHostingError::AppNotFound)?;

    let env = repositories::environment_summary_by_id(db, deployment.environment_id.id)
        .await?
        .ok_or(WebHostingError::EnvironmentNotFound)?;

    let release_public_id = match deployment.release_id {
        Some(ref rel) => repositories::release_summary_by_id(db, *rel)
            .await?
            .map(|r| r.public_id),
        None => None,
    };

    let user_id_str = deployment.deployed_by_id.to_string();

    Ok(WebDeploymentDetail {
        deployment,
        app_public_id: app.public_id,
        environment_public_id: env.public_id,
        release_public_id,
        deployed_by_public_id: user_id_str,
    })
}

/// List web deployments in an organization, optionally filtered by app, environment, target, or status.
pub async fn list_web_deployments(
    db: &Database,
    organization_id: i64,
    app_public_id: Option<&str>,
    environment_public_id: Option<&str>,
    target_filter: Option<&str>,
    status_filter: Option<&str>,
) -> Result<Vec<WebDeploymentDetail>, WebHostingError> {
    let deployments = if let Some(app_pub_id) = app_public_id {
        let app = repositories::app_summary_by_public_id_and_org(db, app_pub_id, organization_id)
            .await?
            .ok_or(WebHostingError::AppNotFound)?;
        repositories::deployments_for_app(db, app.id, organization_id).await?
    } else {
        repositories::deployments_for_organization(db, organization_id).await?
    };

    let mut results = Vec::new();
    for d in deployments {
        if let Some(target) = target_filter {
            if d.target != target {
                continue;
            }
        }
        if let Some(status) = status_filter {
            if d.status != status {
                continue;
            }
        }
        if let Some(env_pub_id) = environment_public_id {
            if let Some(env) =
                repositories::environment_summary_by_id(db, d.environment_id.id).await?
            {
                if env.public_id != env_pub_id {
                    continue;
                }
            } else {
                continue;
            }
        }

        let app = repositories::app_summary_by_id(db, d.app_id.id)
            .await?
            .ok_or(WebHostingError::AppNotFound)?;

        let env = repositories::environment_summary_by_id(db, d.environment_id.id)
            .await?
            .ok_or(WebHostingError::EnvironmentNotFound)?;

        let release_public_id = match d.release_id {
            Some(ref rel) => repositories::release_summary_by_id(db, *rel)
                .await?
                .map(|r| r.public_id),
            None => None,
        };

        let user_id_str = d.deployed_by_id.to_string();

        results.push(WebDeploymentDetail {
            deployment: d,
            app_public_id: app.public_id,
            environment_public_id: env.public_id,
            release_public_id,
            deployed_by_public_id: user_id_str,
        });
    }

    Ok(results)
}

/// Register a custom domain for an application.
pub async fn create_custom_domain(
    db: &Database,
    organization_id: i64,
    req: CreateCustomDomainRequest,
) -> Result<CustomDomainDetail, WebHostingError> {
    let clean_domain = validate_domain(&req.domain)?;

    let app = repositories::app_summary_by_public_id_and_org(db, &req.app_id, organization_id)
        .await?
        .ok_or(WebHostingError::AppNotFound)?;

    // Check for existing domain on this app
    if repositories::custom_domain_by_app_and_domain(db, app.id, &clean_domain)
        .await?
        .is_some()
    {
        return Err(WebHostingError::DomainAlreadyExists);
    }

    let domain = CustomDomain {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        app_id: ForeignKey::new(app.id),
        organization_id,
        domain: clean_domain,
        certificate_status: "pending".to_string(),
        certificate_expires_at: None,
        verified_at: None,
        created_at: Utc::now(),
    };

    let saved = repositories::insert_custom_domain(db, domain).await?;

    Ok(CustomDomainDetail {
        domain: saved,
        app_public_id: app.public_id,
    })
}

/// Delete a custom domain by its public UUID within an organization.
pub async fn delete_custom_domain(
    db: &Database,
    organization_id: i64,
    domain_public_id: &str,
) -> Result<(), WebHostingError> {
    let domain =
        repositories::custom_domain_by_public_id_and_org(db, domain_public_id, organization_id)
            .await?
            .ok_or(WebHostingError::DomainNotFound)?;

    repositories::delete_custom_domain_by_id(db, domain.id).await?;
    Ok(())
}

/// List custom domains in an organization, optionally filtered by app.
pub async fn list_custom_domains(
    db: &Database,
    organization_id: i64,
    app_public_id: Option<&str>,
) -> Result<Vec<CustomDomainDetail>, WebHostingError> {
    let domains = if let Some(app_pub_id) = app_public_id {
        let app = repositories::app_summary_by_public_id_and_org(db, app_pub_id, organization_id)
            .await?
            .ok_or(WebHostingError::AppNotFound)?;
        repositories::custom_domains_for_app(db, app.id, organization_id).await?
    } else {
        repositories::custom_domains_for_organization(db, organization_id).await?
    };

    let mut results = Vec::with_capacity(domains.len());
    for d in domains {
        if let Some(app) = repositories::app_summary_by_id(db, d.app_id.id).await? {
            results.push(CustomDomainDetail {
                domain: d,
                app_public_id: app.public_id,
            });
        }
    }

    Ok(results)
}
