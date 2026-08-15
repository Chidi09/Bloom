//! Business logic, domain rules, and transactional operations for `projects`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use rand::Rng;
use uuid::Uuid;

use super::contracts::{ProjectCreateRequest, ProjectUpdateRequest};
use super::errors::ProjectError;
use super::models::Project;
use super::repositories;

/// Convert a string into a clean, URL-safe slug.
pub fn slugify(name: &str) -> String {
    let mut slug = String::with_capacity(name.len());
    let mut last_was_dash = true;

    for c in name.chars() {
        if c.is_ascii_alphanumeric() {
            slug.push(c.to_ascii_lowercase());
            last_was_dash = false;
        } else if (c == ' ' || c == '-' || c == '_' || c == '.') && !last_was_dash {
            slug.push('-');
            last_was_dash = true;
        }
    }

    let trimmed = slug.trim_matches('-');
    if trimmed.is_empty() {
        "project".to_string()
    } else if trimmed.len() > 60 {
        trimmed[..60].trim_matches('-').to_string()
    } else {
        trimmed.to_string()
    }
}

/// Generate a unique slug within an organization by checking existing records.
pub async fn generate_unique_slug_in_org(
    db: &Database,
    organization_id: i64,
    base_slug: &str,
) -> Result<String, ProjectError> {
    let base = if base_slug.len() > 55 {
        &base_slug[..55]
    } else {
        base_slug
    };

    if !repositories::project_slug_exists_in_org(db, organization_id, base).await? {
        return Ok(base.to_string());
    }

    for counter in 2..1000 {
        let candidate = format!("{base}-{counter}");
        if !repositories::project_slug_exists_in_org(db, organization_id, &candidate).await? {
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

/// Create a new project within an organization.
pub async fn create_project(
    db: &Database,
    organization_id: i64,
    req: ProjectCreateRequest,
) -> Result<Project, ProjectError> {
    let trimmed_name = req.name.trim();
    if trimmed_name.is_empty() {
        return Err(ProjectError::ValidationError(
            "Project name cannot be empty.".to_string(),
        ));
    }
    if trimmed_name.len() > 255 {
        return Err(ProjectError::ValidationError(
            "Project name cannot exceed 255 characters.".to_string(),
        ));
    }

    let description = match req.description {
        Some(desc) => {
            let trimmed = desc.trim();
            if trimmed.len() > 1000 {
                return Err(ProjectError::ValidationError(
                    "Project description cannot exceed 1000 characters.".to_string(),
                ));
            }
            if trimmed.is_empty() {
                None
            } else {
                Some(trimmed.to_string())
            }
        }
        None => None,
    };

    let base_slug = slugify(trimmed_name);
    let unique_slug = generate_unique_slug_in_org(db, organization_id, &base_slug).await?;

    let now = Utc::now();
    let project = Project {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        organization_id: ForeignKey::new(organization_id),
        name: trimmed_name.to_string(),
        slug: unique_slug,
        description,
        created_at: now,
        updated_at: now,
    };

    let saved_project = repositories::insert_project(db, project).await?;

    // TODO(spec): Emit project.created event via events::publish (payload: { project_id, organization_id })

    Ok(saved_project)
}

/// Retrieve a single project by public UUID, scoped to an organization.
pub async fn get_project(
    db: &Database,
    organization_id: i64,
    project_public_id: &str,
) -> Result<Project, ProjectError> {
    repositories::project_by_public_id_and_org(db, project_public_id, organization_id)
        .await?
        .ok_or(ProjectError::ProjectNotFound)
}

/// Retrieve all projects for an organization, ordered by `-created_at`.
pub async fn list_projects_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Project>, ProjectError> {
    repositories::projects_for_organization(db, organization_id)
        .await
        .map_err(Into::into)
}

/// Update an existing project partially.
pub async fn update_project(
    db: &Database,
    project: &mut Project,
    req: ProjectUpdateRequest,
) -> Result<Project, ProjectError> {
    let mut modified = false;

    if let Some(name) = req.name {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(ProjectError::ValidationError(
                "Project name cannot be empty.".to_string(),
            ));
        }
        if trimmed.len() > 255 {
            return Err(ProjectError::ValidationError(
                "Project name cannot exceed 255 characters.".to_string(),
            ));
        }

        if trimmed != project.name {
            project.name = trimmed.to_string();
            let base_slug = slugify(trimmed);
            let unique_slug =
                generate_unique_slug_in_org(db, project.organization_id.id, &base_slug).await?;
            project.slug = unique_slug;
            modified = true;
        }
    }

    if let Some(description) = req.description {
        let trimmed = description.trim();
        if trimmed.len() > 1000 {
            return Err(ProjectError::ValidationError(
                "Project description cannot exceed 1000 characters.".to_string(),
            ));
        }
        let new_desc = if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_string())
        };
        if new_desc != project.description {
            project.description = new_desc;
            modified = true;
        }
    }

    if modified {
        project.updated_at = Utc::now();
        repositories::update_project(db, project).await?;

        // TODO(spec): Emit project.updated event via events::publish (payload: { project_id })
    }

    Ok(project.clone())
}

/// Delete a project from an organization, ensuring it has no attached apps.
pub async fn delete_project(db: &Database, project: &Project) -> Result<(), ProjectError> {
    let app_count = repositories::count_apps_in_project(db, project.id).await?;
    if app_count > 0 {
        return Err(ProjectError::ProjectNotEmpty);
    }

    repositories::delete_project_by_id(db, project.id).await?;

    // TODO(spec): Emit project.deleted event via events::publish (payload: { project_id })

    Ok(())
}
