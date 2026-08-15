//! Serializers and representation converters for the `apps` app.

use super::contracts::AppResponse;
use super::models::App;

/// Serializes an `App` model instance into an `AppResponse` wire contract.
///
/// `project_public_id` and `organization_public_id` are the external UUID strings
/// corresponding to the foreign keys on the model.
pub fn serialize_app(
    app: &App,
    project_public_id: &str,
    organization_public_id: &str,
) -> AppResponse {
    AppResponse {
        id: app.public_id.clone(),
        project_id: project_public_id.to_string(),
        organization_id: organization_public_id.to_string(),
        name: app.name.clone(),
        slug: app.slug.clone(),
        repository_url: app.repository_url.clone(),
        default_branch: app.default_branch.clone(),
        created_at: app.created_at.to_rfc3339(),
        updated_at: app.updated_at.to_rfc3339(),
    }
}
