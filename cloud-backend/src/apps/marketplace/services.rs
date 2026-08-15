//! Business logic, state transitions, and workflows for `marketplace`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{
    TemplateCreateRequest, TemplatePublishRequest, TemplateUpdateRequest,
    TemplateVersionCreateRequest,
};
use super::errors::MarketplaceError;
use super::models::{Template, TemplateVersion};
use super::repositories;

// TODO(spec): Monetization and paid template billing workflows deferred per Phase 8 specification.
// TODO(spec): Template reviews, ratings, and community moderation workflows deferred per Phase 8 specification.
// TODO(spec): Template install analytics and download counters deferred per Phase 8 specification.
// TODO(spec): Featured placement and marketplace curation workflows deferred per Phase 8 specification.

/// Emits an event to the system events log.
///
/// Delegates to the `events` app's public service interface, which logs and swallows any
/// recording failure so that event logging never fails the primary business write.
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

/// Valid visibility scopes for templates.
pub const VALID_VISIBILITIES: &[&str] = &["private", "public"];

/// All valid template lifecycle statuses.
pub const VALID_STATUSES: &[&str] = &["draft", "published", "archived"];

/// Returns `true` when `from -> to` is a legal template status transition.
///
/// State transition rules:
/// - `draft`: can advance to `published` (published to marketplace/org), or `archived` (discarded draft).
/// - `published`: can return to `draft` (unpublish / return to staging), or advance to `archived` (deprecated/retired).
/// - `archived`: strictly absorbing terminal state (no transitions out).
pub fn can_transition(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("draft", "published")
            | ("draft", "archived")
            | ("published", "draft")
            | ("published", "archived")
    )
}

/// Convert a template name into a clean, URL-safe slug.
pub fn slugify(name: &str) -> String {
    let mut slug = String::new();
    let mut prev_dash = false;

    for c in name.chars() {
        if c.is_alphanumeric() {
            slug.push(c.to_ascii_lowercase());
            prev_dash = false;
        } else if !prev_dash {
            slug.push('-');
            prev_dash = true;
        }
    }

    let trimmed = slug.trim_matches('-');
    if trimmed.is_empty() {
        "template".to_string()
    } else if trimmed.len() > 60 {
        trimmed[..60].trim_matches('-').to_string()
    } else {
        trimmed.to_string()
    }
}

/// Validate that a version string is a valid semver format (e.g. `1.0.0`, `v2.1.0-beta`).
pub fn validate_version(version: &str) -> Result<(), MarketplaceError> {
    let trimmed = version.trim();
    if trimmed.is_empty() {
        return Err(MarketplaceError::ValidationError(
            "Version cannot be empty.".to_string(),
        ));
    }
    if trimmed.len() > 64 {
        return Err(MarketplaceError::ValidationError(
            "Version string exceeds 64 characters.".to_string(),
        ));
    }
    let v_stripped = trimmed.strip_prefix('v').unwrap_or(trimmed);
    let parts: Vec<&str> = v_stripped.split('.').collect();
    if parts.is_empty() || !parts[0].chars().any(|c| c.is_ascii_digit()) {
        return Err(MarketplaceError::ValidationError(format!(
            "Invalid version format: '{version}'. Must follow semantic versioning (e.g. 1.0.0)."
        )));
    }
    Ok(())
}

/// Validate visibility against [`VALID_VISIBILITIES`].
pub fn validate_visibility(visibility: &str) -> Result<(), MarketplaceError> {
    if VALID_VISIBILITIES.contains(&visibility) {
        Ok(())
    } else {
        Err(MarketplaceError::ValidationError(format!(
            "Invalid visibility '{visibility}'. Allowed values: {}.",
            VALID_VISIBILITIES.join(", ")
        )))
    }
}

/// Validate status against [`VALID_STATUSES`].
pub fn validate_status(status: &str) -> Result<(), MarketplaceError> {
    if VALID_STATUSES.contains(&status) {
        Ok(())
    } else {
        Err(MarketplaceError::ValidationError(format!(
            "Invalid status '{status}'. Allowed values: {}.",
            VALID_STATUSES.join(", ")
        )))
    }
}

/// Detailed composite representation of a template and its versions.
#[derive(Debug, Clone)]
pub struct TemplateDetail {
    /// The template database model.
    pub template: Template,
    /// Owning organization's public UUID v4.
    pub organization_public_id: String,
    /// Associated versions.
    pub versions: Vec<TemplateVersion>,
    /// Latest semver version string, if any.
    pub latest_version: Option<String>,
    /// Count of published versions.
    pub versions_count: i64,
}

/// Detailed representation of a template version and its parent.
#[derive(Debug, Clone)]
pub struct TemplateVersionDetail {
    /// The template version database model.
    pub version: TemplateVersion,
    /// Parent template's public UUID v4.
    pub template_public_id: String,
}

/// Create a new template in `draft` status within an organization.
pub async fn create_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    req: TemplateCreateRequest,
) -> Result<TemplateDetail, MarketplaceError> {
    let name_trimmed = req.name.trim();
    if name_trimmed.is_empty() {
        return Err(MarketplaceError::ValidationError(
            "Template name cannot be empty.".to_string(),
        ));
    }
    if name_trimmed.len() > 255 {
        return Err(MarketplaceError::ValidationError(
            "Template name exceeds 255 characters.".to_string(),
        ));
    }

    let visibility = req
        .visibility
        .as_deref()
        .map(|v| v.trim().to_lowercase())
        .unwrap_or_else(|| "private".to_string());
    validate_visibility(&visibility)?;

    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let base_slug = slugify(name_trimmed);
    let mut candidate_slug = base_slug.clone();
    let mut counter = 1;

    while repositories::template_slug_exists_in_org(db, organization_id, &candidate_slug)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    {
        candidate_slug = format!("{base_slug}-{counter}");
        counter += 1;
    }

    let metadata_str = match req.metadata {
        Some(ref val) => serde_json::to_string(val).unwrap_or_else(|_| "{}".to_string()),
        None => "{}".to_string(),
    };

    let template = Template {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        organization_id: ForeignKey::new(organization_id),
        name: name_trimmed.to_string(),
        slug: candidate_slug,
        description: req.description.map(|d| d.trim().to_string()),
        visibility,
        status: "draft".to_string(),
        metadata: metadata_str,
        created_by_id: actor_id,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let saved = repositories::insert_template(db, template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "template.created",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": saved.public_id,
            "organization_id": org_summary.public_id,
            "name": saved.name,
            "slug": saved.slug,
            "visibility": saved.visibility,
            "status": saved.status,
        }),
    )
    .await;

    Ok(TemplateDetail {
        template: saved,
        organization_public_id: org_summary.public_id,
        versions: Vec::new(),
        latest_version: None,
        versions_count: 0,
    })
}

/// List all templates belonging to an organization.
pub async fn list_org_templates(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<TemplateDetail>, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let templates = repositories::templates_for_organization(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let mut details = Vec::with_capacity(templates.len());
    for t in templates {
        let latest = repositories::latest_version_for_template(db, t.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
        let count = repositories::count_versions_for_template(db, t.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

        details.push(TemplateDetail {
            template: t,
            organization_public_id: org_summary.public_id.clone(),
            versions: Vec::new(),
            latest_version: latest.map(|v| v.version),
            versions_count: count,
        });
    }

    Ok(details)
}

/// Retrieve a template by public UUID within an organization.
pub async fn get_org_template(
    db: &Database,
    organization_id: i64,
    template_public_id: &str,
) -> Result<TemplateDetail, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let latest_version = versions.first().map(|v| v.version.clone());
    let versions_count = versions.len() as i64;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_summary.public_id,
        versions,
        latest_version,
        versions_count,
    })
}

/// Partially update an organization template.
pub async fn update_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
    req: TemplateUpdateRequest,
) -> Result<TemplateDetail, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let mut template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    if let Some(ref name) = req.name {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(MarketplaceError::ValidationError(
                "Template name cannot be empty.".to_string(),
            ));
        }
        if trimmed.len() > 255 {
            return Err(MarketplaceError::ValidationError(
                "Template name exceeds 255 characters.".to_string(),
            ));
        }
        template.name = trimmed.to_string();
    }

    if let Some(ref desc) = req.description {
        template.description = Some(desc.trim().to_string());
    }

    if let Some(ref vis) = req.visibility {
        let vis_lower = vis.trim().to_lowercase();
        validate_visibility(&vis_lower)?;
        template.visibility = vis_lower;
    }

    let mut status_changed = false;
    if let Some(ref target_status) = req.status {
        let target_lower = target_status.trim().to_lowercase();
        validate_status(&target_lower)?;
        if target_lower != template.status {
            if !can_transition(&template.status, &target_lower) {
                return Err(MarketplaceError::InvalidStateTransition {
                    from: template.status.clone(),
                    to: target_lower,
                });
            }
            template.status = target_lower;
            status_changed = true;
        }
    }

    if let Some(ref meta) = req.metadata {
        template.metadata = serde_json::to_string(meta).unwrap_or_else(|_| "{}".to_string());
    }

    template.updated_at = Utc::now();
    repositories::update_template(db, &template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let event_type = if status_changed && template.status == "published" {
        "template.published"
    } else if status_changed && template.status == "archived" {
        "template.archived"
    } else {
        "template.updated"
    };

    emit_event(
        db,
        event_type,
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "organization_id": org_summary.public_id,
            "name": template.name,
            "visibility": template.visibility,
            "status": template.status,
        }),
    )
    .await;

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let latest_version = versions.first().map(|v| v.version.clone());
    let versions_count = versions.len() as i64;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_summary.public_id,
        versions,
        latest_version,
        versions_count,
    })
}

/// Explicitly publish a template.
pub async fn publish_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
    req: TemplatePublishRequest,
) -> Result<TemplateDetail, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let mut template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    if template.status != "published" {
        if !can_transition(&template.status, "published") {
            return Err(MarketplaceError::InvalidStateTransition {
                from: template.status.clone(),
                to: "published".to_string(),
            });
        }
        template.status = "published".to_string();
    }

    if let Some(ref vis) = req.visibility {
        let vis_lower = vis.trim().to_lowercase();
        validate_visibility(&vis_lower)?;
        template.visibility = vis_lower;
    }

    template.updated_at = Utc::now();
    repositories::update_template(db, &template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "template.published",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "organization_id": org_summary.public_id,
            "visibility": template.visibility,
            "status": template.status,
        }),
    )
    .await;

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let latest_version = versions.first().map(|v| v.version.clone());
    let versions_count = versions.len() as i64;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_summary.public_id,
        versions,
        latest_version,
        versions_count,
    })
}

/// Explicitly archive a template.
pub async fn archive_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
) -> Result<TemplateDetail, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let mut template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    if template.status != "archived" {
        if !can_transition(&template.status, "archived") {
            return Err(MarketplaceError::InvalidStateTransition {
                from: template.status.clone(),
                to: "archived".to_string(),
            });
        }
        template.status = "archived".to_string();
    }

    template.updated_at = Utc::now();
    repositories::update_template(db, &template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "template.archived",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "organization_id": org_summary.public_id,
            "status": template.status,
        }),
    )
    .await;

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let latest_version = versions.first().map(|v| v.version.clone());
    let versions_count = versions.len() as i64;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_summary.public_id,
        versions,
        latest_version,
        versions_count,
    })
}

/// Delete a template and cascade delete its versions.
pub async fn delete_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
) -> Result<(), MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    repositories::delete_template_by_id(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "template.deleted",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "organization_id": org_summary.public_id,
            "name": template.name,
        }),
    )
    .await;

    Ok(())
}

/// List public published templates for the marketplace catalog.
///
/// Private or unpublished templates are strictly excluded from results.
pub async fn list_public_templates(
    db: &Database,
    search: Option<&str>,
) -> Result<Vec<TemplateDetail>, MarketplaceError> {
    let templates = repositories::public_published_templates(db, search)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let mut details = Vec::with_capacity(templates.len());
    for t in templates {
        let org_summary = repositories::organization_summary_by_id(db, t.organization_id.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
        let org_pub = org_summary
            .map(|o| o.public_id)
            .unwrap_or_else(|| "org".to_string());

        let latest = repositories::latest_version_for_template(db, t.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
        let count = repositories::count_versions_for_template(db, t.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

        details.push(TemplateDetail {
            template: t,
            organization_public_id: org_pub,
            versions: Vec::new(),
            latest_version: latest.map(|v| v.version),
            versions_count: count,
        });
    }

    Ok(details)
}

/// Look up a public published template by UUID or slug.
///
/// Returns `TemplateNotFound` if the template does not exist, is private, or is unpublished.
pub async fn get_public_template(
    db: &Database,
    template_public_id_or_slug: &str,
) -> Result<TemplateDetail, MarketplaceError> {
    let template =
        repositories::public_published_template_by_public_id(db, template_public_id_or_slug)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let template = match template {
        Some(t) => t,
        None => {
            // Check if template exists by public_id or slug to return the correct error
            let maybe_t = repositories::template_by_public_id(db, template_public_id_or_slug)
                .await
                .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

            match maybe_t {
                Some(t) => {
                    if t.visibility != "public" {
                        return Err(MarketplaceError::TemplatePrivate);
                    }
                    if t.status != "published" {
                        return Err(MarketplaceError::TemplateNotPublished);
                    }
                    t
                }
                None => return Err(MarketplaceError::TemplateNotFound),
            }
        }
    };

    let org_summary = repositories::organization_summary_by_id(db, template.organization_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let org_pub = org_summary
        .map(|o| o.public_id)
        .unwrap_or_else(|| "org".to_string());

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let latest_version = versions.first().map(|v| v.version.clone());
    let versions_count = versions.len() as i64;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_pub,
        versions,
        latest_version,
        versions_count,
    })
}

/// Create a new version for an organization template.
pub async fn create_template_version(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
    req: TemplateVersionCreateRequest,
) -> Result<TemplateVersionDetail, MarketplaceError> {
    validate_version(&req.version)?;

    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    let existing = repositories::version_by_semver_and_template(db, &req.version, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    if existing.is_some() {
        return Err(MarketplaceError::VersionAlreadyExists);
    }

    let manifest_str = match req.manifest {
        Some(ref val) => serde_json::to_string(val).unwrap_or_else(|_| "{}".to_string()),
        None => "{}".to_string(),
    };

    let version = TemplateVersion {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        template_id: ForeignKey::new(template.id),
        version: req.version.trim().to_string(),
        changelog: req.changelog.unwrap_or_default(),
        manifest: manifest_str,
        readme: req.readme.unwrap_or_default(),
        created_by_id: actor_id,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let saved = repositories::insert_version(db, version)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "template.version.created",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "version_id": saved.public_id,
            "version": saved.version,
        }),
    )
    .await;

    Ok(TemplateVersionDetail {
        version: saved,
        template_public_id: template.public_id,
    })
}

/// List all versions belonging to a template within an organization.
pub async fn list_template_versions(
    db: &Database,
    organization_id: i64,
    template_public_id: &str,
) -> Result<Vec<TemplateVersionDetail>, MarketplaceError> {
    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    Ok(versions
        .into_iter()
        .map(|v| TemplateVersionDetail {
            version: v,
            template_public_id: template.public_id.clone(),
        })
        .collect())
}

/// Retrieve a specific template version by public UUID within an organization.
pub async fn get_template_version(
    db: &Database,
    organization_id: i64,
    template_public_id: &str,
    version_public_id: &str,
) -> Result<TemplateVersionDetail, MarketplaceError> {
    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    let version =
        repositories::version_by_public_id_and_template(db, version_public_id, template.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateVersionNotFound)?;

    Ok(TemplateVersionDetail {
        version,
        template_public_id: template.public_id,
    })
}

/// Delete a template version by public UUID.
pub async fn delete_template_version(
    db: &Database,
    organization_id: i64,
    _actor_id: i64,
    template_public_id: &str,
    version_public_id: &str,
) -> Result<(), MarketplaceError> {
    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    let version =
        repositories::version_by_public_id_and_template(db, version_public_id, template.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateVersionNotFound)?;

    repositories::delete_version_by_id(db, version.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    Ok(())
}

/// Retrieve a specific version of a public published template.
pub async fn get_public_template_version(
    db: &Database,
    template_public_id: &str,
    version_public_id: &str,
) -> Result<TemplateVersionDetail, MarketplaceError> {
    let template = repositories::public_published_template_by_public_id(db, template_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let template = match template {
        Some(t) => t,
        None => {
            let maybe_t = repositories::template_by_public_id(db, template_public_id)
                .await
                .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
            match maybe_t {
                Some(t) => {
                    if t.visibility != "public" {
                        return Err(MarketplaceError::TemplatePrivate);
                    }
                    if t.status != "published" {
                        return Err(MarketplaceError::TemplateNotPublished);
                    }
                    t
                }
                None => return Err(MarketplaceError::TemplateNotFound),
            }
        }
    };

    let version =
        repositories::version_by_public_id_and_template(db, version_public_id, template.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateVersionNotFound)?;

    Ok(TemplateVersionDetail {
        version,
        template_public_id: template.public_id,
    })
}
