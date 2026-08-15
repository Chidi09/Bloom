//! Serialization and DTO mapping for `marketplace`.

use super::contracts::{
    TemplateDetailResponse, TemplateResponse, TemplateVersionResponse,
    TemplateVersionSummaryResponse,
};
use super::models::{Template, TemplateVersion};

/// Parse a JSON-in-TEXT string safely back to a [`serde_json::Value`].
///
/// Falls back to an empty JSON object `{}` on unparseable or empty input without panicking.
pub fn parse_json_safely(raw: &str) -> serde_json::Value {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return serde_json::json!({});
    }
    serde_json::from_str(trimmed).unwrap_or_else(|_| serde_json::json!({}))
}

/// Serialize a [`Template`] into a public wire [`TemplateResponse`].
pub fn serialize_template(
    template: &Template,
    organization_public_id: &str,
    latest_version: Option<String>,
    versions_count: i64,
) -> TemplateResponse {
    TemplateResponse {
        id: template.public_id.clone(),
        organization_id: organization_public_id.to_string(),
        name: template.name.clone(),
        slug: template.slug.clone(),
        description: template.description.clone(),
        visibility: template.visibility.clone(),
        status: template.status.clone(),
        metadata: parse_json_safely(&template.metadata),
        latest_version,
        versions_count,
        created_at: template.created_at.to_rfc3339(),
        updated_at: template.updated_at.to_rfc3339(),
    }
}

/// Serialize a [`Template`] with its version summaries into [`TemplateDetailResponse`].
pub fn serialize_template_detail(
    template: &Template,
    organization_public_id: &str,
    versions: &[TemplateVersion],
) -> TemplateDetailResponse {
    let version_summaries = versions.iter().map(serialize_version_summary).collect();

    TemplateDetailResponse {
        id: template.public_id.clone(),
        organization_id: organization_public_id.to_string(),
        name: template.name.clone(),
        slug: template.slug.clone(),
        description: template.description.clone(),
        visibility: template.visibility.clone(),
        status: template.status.clone(),
        metadata: parse_json_safely(&template.metadata),
        versions: version_summaries,
        created_at: template.created_at.to_rfc3339(),
        updated_at: template.updated_at.to_rfc3339(),
    }
}

/// Serialize a [`TemplateVersion`] into a public wire [`TemplateVersionResponse`].
pub fn serialize_template_version(
    version: &TemplateVersion,
    template_public_id: &str,
) -> TemplateVersionResponse {
    TemplateVersionResponse {
        id: version.public_id.clone(),
        template_id: template_public_id.to_string(),
        version: version.version.clone(),
        changelog: version.changelog.clone(),
        manifest: parse_json_safely(&version.manifest),
        readme: version.readme.clone(),
        created_at: version.created_at.to_rfc3339(),
        updated_at: version.updated_at.to_rfc3339(),
    }
}

/// Serialize a [`TemplateVersion`] into a lightweight summary [`TemplateVersionSummaryResponse`].
pub fn serialize_version_summary(version: &TemplateVersion) -> TemplateVersionSummaryResponse {
    TemplateVersionSummaryResponse {
        id: version.public_id.clone(),
        version: version.version.clone(),
        changelog: version.changelog.clone(),
        created_at: version.created_at.to_rfc3339(),
    }
}
