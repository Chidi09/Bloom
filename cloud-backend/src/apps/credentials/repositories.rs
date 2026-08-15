//! Database access and QuerySet operations for the `credentials` app.

use chrono::{DateTime, Utc};
use djangors_db::Database;
use djangors_orm::expr::IntoSetExpr;
use djangors_orm::{q, Model, OrmError};

use super::models::Credential;

/// Fetch a `Credential` by internal primary key.
pub async fn credential_by_id(db: &Database, id: i64) -> Result<Option<Credential>, OrmError> {
    Credential::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `Credential` by public UUID.
pub async fn credential_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<Credential>, OrmError> {
    Credential::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `Credential` by public UUID and organization ID (scoped check).
pub async fn credential_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Credential>, OrmError> {
    Credential::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Check if a credential with the given name exists in an organization.
pub async fn credential_name_exists_in_org(
    db: &Database,
    organization_id: i64,
    name: &str,
) -> Result<bool, OrmError> {
    Credential::objects()
        .filter(q!(organization_id = organization_id))?
        .filter(q!(name = name.to_owned()))?
        .exists(db)
        .await
}

/// List all credentials belonging to an organization, ordered by newest first (`-created_at`).
pub async fn credentials_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Credential>, OrmError> {
    Credential::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List credentials belonging to an organization with pagination (LIMIT/OFFSET).
pub async fn list_credentials_query(
    db: &Database,
    organization_id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<Credential>, i64), OrmError> {
    let mut qs = Credential::objects().filter(q!(organization_id = organization_id))?;
    let total = qs.clone().count(db).await?;
    qs = qs.order_by("-created_at")?;
    if let Some(l) = limit {
        qs = qs.limit(l);
    }
    if let Some(o) = offset {
        qs = qs.offset(o);
    }
    let rows = qs.all(db).await?;
    Ok((rows, total))
}

/// Insert a new `Credential` record.
pub async fn insert_credential(
    db: &Database,
    credential: Credential,
) -> Result<Credential, OrmError> {
    credential.save(db).await
}

/// Update an existing `Credential` record.
pub async fn update_credential(db: &Database, credential: &Credential) -> Result<(), OrmError> {
    credential.update(db).await
}

/// Update the `last_used_at` timestamp of a `Credential`.
pub async fn update_credential_last_used(
    db: &Database,
    id: i64,
    last_used: DateTime<Utc>,
) -> Result<u64, OrmError> {
    Credential::objects()
        .filter(q!(id = id))?
        .update(db, vec![("last_used_at", last_used.into_set_expr())])
        .await
}

/// Delete a `Credential` by internal primary key.
pub async fn delete_credential_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    Credential::objects().filter(q!(id = id))?.delete(db).await
}
