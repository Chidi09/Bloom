//! Business logic, transactional workflows, and domain rules for `apps`.

use chrono::Utc;
use djangors_db::Database;
use rand::Rng;
use uuid::Uuid;

use super::contracts::{AppCreateRequest, AppLinkRequest, AppUpdateRequest};
use super::errors::AppError;
use super::models::App;
use super::repositories::{self, OrganizationSummary, ProjectSummary};

/// Convert a string into a clean, URL-safe slug.
pub fn slugify(name: &str) -> String {
    crate::apps::common::slug::slugify(name, "app")
}

/// Generate a unique slug for an app within a project.
pub async fn generate_unique_slug(
    db: &Database,
    project_id: i64,
    base_slug: &str,
) -> Result<String, AppError> {
    let base = if base_slug.len() > 55 {
        &base_slug[..55]
    } else {
        base_slug
    };

    if !repositories::app_slug_exists_in_project(db, project_id, base).await? {
        return Ok(base.to_string());
    }

    for counter in 2..1000 {
        let candidate = format!("{base}-{counter}");
        if !repositories::app_slug_exists_in_project(db, project_id, &candidate).await? {
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

/// Create a new `App` entity scoped to a project and organization.
pub async fn create_app(
    db: &Database,
    organization_id: i64,
    actor_user_id: Option<i64>,
    req: AppCreateRequest,
) -> Result<(App, ProjectSummary, OrganizationSummary), AppError> {
    let trimmed_name = req.name.trim();
    if trimmed_name.is_empty() {
        return Err(AppError::ValidationError(
            "App name cannot be empty.".to_string(),
        ));
    }
    if trimmed_name.len() > 255 {
        return Err(AppError::ValidationError(
            "App name cannot exceed 255 characters.".to_string(),
        ));
    }

    // 1. Resolve project by public UUID and ensure it belongs to the active organization
    let project = repositories::project_by_public_id_and_org(db, &req.project_id, organization_id)
        .await?
        .ok_or(AppError::ProjectNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(AppError::OrganizationNotFound)?;

    // 2. Generate unique slug within the project
    let base_slug = slugify(trimmed_name);
    let unique_slug = generate_unique_slug(db, project.id, &base_slug).await?;

    let default_branch = req
        .default_branch
        .map(|b| b.trim().to_string())
        .filter(|b| !b.is_empty())
        .unwrap_or_else(|| "main".to_string());

    let repository_url = req
        .repository_url
        .map(|u| u.trim().to_string())
        .filter(|u| !u.is_empty());

    let now = Utc::now();
    let app = App {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        project_id: project.id,
        organization_id,
        name: trimmed_name.to_string(),
        slug: unique_slug,
        repository_url,
        default_branch,
        created_at: now,
        updated_at: now,
    };

    let saved_app = repositories::insert_app(db, app).await?;

    // 3. Emit app.created event
    emit_event(
        db,
        "app.created",
        Some(organization_id),
        Some(project.id),
        Some(saved_app.id),
        actor_user_id,
        serde_json::json!({
            "app_id": saved_app.public_id,
            "project_id": project.public_id,
        }),
    )
    .await;

    Ok((saved_app, project, org))
}

/// Link a local directory to an app via the CLI flow (resolves by project slug and app slug).
pub async fn link_app(
    db: &Database,
    organization_id: i64,
    req: AppLinkRequest,
) -> Result<(App, ProjectSummary, OrganizationSummary), AppError> {
    let project_slug = req.project_slug.trim();
    let app_slug = req.app_slug.trim();

    if project_slug.is_empty() || app_slug.is_empty() {
        return Err(AppError::ValidationError(
            "Project slug and app slug are required.".to_string(),
        ));
    }

    let project = repositories::project_by_slug_and_org(db, project_slug, organization_id)
        .await?
        .ok_or(AppError::ProjectNotFound)?;

    let app = repositories::app_by_project_and_slug(db, project.id, app_slug)
        .await?
        .ok_or(AppError::AppNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(AppError::OrganizationNotFound)?;

    Ok((app, project, org))
}

/// Retrieve an app by its public UUID within an organization.
pub async fn get_app(
    db: &Database,
    organization_id: i64,
    app_public_id: &str,
) -> Result<(App, ProjectSummary, OrganizationSummary), AppError> {
    let app = repositories::app_by_public_id_and_org(db, app_public_id, organization_id)
        .await?
        .ok_or(AppError::AppNotFound)?;

    let project = repositories::project_summary_by_id(db, app.project_id)
        .await?
        .ok_or(AppError::ProjectNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(AppError::OrganizationNotFound)?;

    Ok((app, project, org))
}

/// List all apps in an organization (or optionally filtered by project), with pagination and N+1 query batching.
pub async fn list_apps(
    db: &Database,
    organization_id: i64,
    project_public_id: Option<&str>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<(App, ProjectSummary, OrganizationSummary)>, i64), AppError> {
    let project_id = if let Some(proj_pub_id) = project_public_id {
        let project = repositories::project_by_public_id_and_org(db, proj_pub_id, organization_id)
            .await?
            .ok_or(AppError::ProjectNotFound)?;
        Some(project.id)
    } else {
        None
    };

    let (apps, total) =
        repositories::list_apps_query(db, organization_id, project_id, limit, offset).await?;

    if apps.is_empty() {
        return Ok((Vec::new(), total));
    }

    // 1. Hoist loop-invariant organization lookup
    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(AppError::OrganizationNotFound)?;

    // 2. Batch-fetch all parent project summaries in ONE query
    let mut project_ids: Vec<i64> = apps.iter().map(|a| a.project_id).collect();
    project_ids.sort_unstable();
    project_ids.dedup();
    let project_map = repositories::project_summaries_by_ids(db, &project_ids).await?;

    let mut results = Vec::with_capacity(apps.len());
    for app in apps {
        if let Some(project) = project_map.get(&app.project_id) {
            results.push((app, project.clone(), org.clone()));
        }
    }

    Ok((results, total))
}

/// Partially update an `App`.
pub async fn update_app(
    db: &Database,
    organization_id: i64,
    actor_user_id: Option<i64>,
    app_public_id: &str,
    req: AppUpdateRequest,
) -> Result<(App, ProjectSummary, OrganizationSummary), AppError> {
    let (mut app, project, org) = get_app(db, organization_id, app_public_id).await?;

    if let Some(name) = req.name {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(AppError::ValidationError(
                "App name cannot be empty.".to_string(),
            ));
        }
        if trimmed.len() > 255 {
            return Err(AppError::ValidationError(
                "App name cannot exceed 255 characters.".to_string(),
            ));
        }
        app.name = trimmed.to_string();
    }

    if let Some(repo_url) = req.repository_url {
        let trimmed = repo_url.trim();
        if trimmed.is_empty() {
            app.repository_url = None;
        } else {
            if trimmed.len() > 500 {
                return Err(AppError::ValidationError(
                    "Repository URL cannot exceed 500 characters.".to_string(),
                ));
            }
            app.repository_url = Some(trimmed.to_string());
        }
    }

    if let Some(branch) = req.default_branch {
        let trimmed = branch.trim();
        if trimmed.is_empty() {
            return Err(AppError::ValidationError(
                "Default branch cannot be empty.".to_string(),
            ));
        }
        if trimmed.len() > 255 {
            return Err(AppError::ValidationError(
                "Default branch cannot exceed 255 characters.".to_string(),
            ));
        }
        app.default_branch = trimmed.to_string();
    }

    app.updated_at = Utc::now();
    repositories::update_app(db, &app).await?;

    // Emit app.updated event
    emit_event(
        db,
        "app.updated",
        Some(organization_id),
        Some(project.id),
        Some(app.id),
        actor_user_id,
        serde_json::json!({
            "app_id": app.public_id,
        }),
    )
    .await;

    Ok((app, project, org))
}

/// Delete an `App` record (refuses if it has environments, builds, or releases).
pub async fn delete_app(
    db: &Database,
    organization_id: i64,
    actor_user_id: Option<i64>,
    app_public_id: &str,
) -> Result<(), AppError> {
    let (app, project, _) = get_app(db, organization_id, app_public_id).await?;

    // Refuse if app has environments/builds/releases
    if repositories::app_has_children(db, app.id).await? {
        return Err(AppError::AppNotEmpty);
    }

    repositories::delete_app_by_id(db, app.id).await?;

    // Emit app.deleted event
    emit_event(
        db,
        "app.deleted",
        Some(organization_id),
        Some(project.id),
        Some(app.id),
        actor_user_id,
        serde_json::json!({
            "app_id": app.public_id,
        }),
    )
    .await;

    Ok(())
}
