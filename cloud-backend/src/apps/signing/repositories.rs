//! Database access and QuerySet operations for the `signing` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::SigningIdentity;

/// Summary of an organization row used across query responses.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OrganizationSummary {
    /// Internal primary key.
    pub id: i64,
    /// Public UUID identifier.
    pub public_id: String,
}

/// Fetch a `SigningIdentity` by internal primary key.
pub async fn signing_identity_by_id(
    db: &Database,
    id: i64,
) -> Result<Option<SigningIdentity>, OrmError> {
    SigningIdentity::objects()
        .filter(q!(id = id))?
        .first(db)
        .await
}

/// Fetch a `SigningIdentity` by its public UUID identifier.
pub async fn signing_identity_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<SigningIdentity>, OrmError> {
    SigningIdentity::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `SigningIdentity` by public UUID and organization ID (scoped check).
pub async fn signing_identity_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<SigningIdentity>, OrmError> {
    SigningIdentity::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// List all `SigningIdentity` records for an organization, ordered by newest first (`-created_at`).
pub async fn signing_identities_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<SigningIdentity>, OrmError> {
    SigningIdentity::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all `SigningIdentity` records for an organization and specific platform.
pub async fn signing_identities_for_org_and_platform(
    db: &Database,
    organization_id: i64,
    platform: &str,
) -> Result<Vec<SigningIdentity>, OrmError> {
    SigningIdentity::objects()
        .filter(q!(organization_id = organization_id))?
        .filter(q!(platform = platform.to_owned()))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// Insert a new `SigningIdentity` record.
pub async fn insert_signing_identity(
    db: &Database,
    identity: SigningIdentity,
) -> Result<SigningIdentity, OrmError> {
    identity.save(db).await
}

/// Update an existing `SigningIdentity` record.
pub async fn update_signing_identity(
    db: &Database,
    identity: &SigningIdentity,
) -> Result<(), OrmError> {
    identity.update(db).await
}

/// Delete a `SigningIdentity` record by its internal primary key.
pub async fn delete_signing_identity_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    SigningIdentity::objects()
        .filter(q!(id = id))?
        .delete(db)
        .await
}

/// Look up an organization summary by its internal primary key.
pub async fn organization_summary_by_id(
    db: &Database,
    organization_id: i64,
) -> Result<Option<OrganizationSummary>, OrmError> {
    let found = crate::apps::organizations::models::Organization::objects()
        .filter(q!(id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(|o| OrganizationSummary {
        id: o.id,
        public_id: o.public_id,
    }))
}
