//! Serialization adapters for the `projects` app.

use super::contracts::ProjectResponse;
use super::models::Project;

/// Serializes a [`Project`] entity into its public API [`ProjectResponse`] representation.
pub fn serialize_project(project: &Project, organization_public_id: &str) -> ProjectResponse {
    ProjectResponse {
        id: project.public_id.clone(),
        organization_id: organization_public_id.to_string(),
        name: project.name.clone(),
        slug: project.slug.clone(),
        description: project.description.clone(),
        created_at: project.created_at.to_rfc3339(),
        updated_at: project.updated_at.to_rfc3339(),
    }
}
