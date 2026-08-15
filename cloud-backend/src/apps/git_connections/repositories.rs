//! Database access and QuerySet operations for the `git_connections` app.

use djangors_db::Database;
use djangors_orm::expr::IntoSetExpr;
use djangors_orm::{q, Model, OrmError};

use super::models::{GitConnection, WebhookDelivery};

/// Resolved summary for an organization entity.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
}

/// Fetch a `GitConnection` by its internal primary key.
pub async fn connection_by_id(db: &Database, id: i64) -> Result<Option<GitConnection>, OrmError> {
    GitConnection::objects()
        .filter(q!(id = id))?
        .first(db)
        .await
}

/// Fetch a `GitConnection` by its external public UUID.
pub async fn connection_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<GitConnection>, OrmError> {
    GitConnection::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `GitConnection` by its external public UUID within a specific organization.
pub async fn connection_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<GitConnection>, OrmError> {
    GitConnection::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch a `GitConnection` by provider and installation ID (e.g. for incoming webhooks).
pub async fn connection_by_provider_and_installation(
    db: &Database,
    provider: &str,
    installation_id: &str,
) -> Result<Option<GitConnection>, OrmError> {
    GitConnection::objects()
        .filter(q!(provider = provider.to_owned()))?
        .filter(q!(installation_id = installation_id.to_owned()))?
        .first(db)
        .await
}

/// Check if a Git connection with the given provider and installation ID exists in an organization.
pub async fn connection_exists_in_org(
    db: &Database,
    organization_id: i64,
    provider: &str,
    installation_id: &str,
) -> Result<bool, OrmError> {
    GitConnection::objects()
        .filter(q!(organization_id = organization_id))?
        .filter(q!(provider = provider.to_owned()))?
        .filter(q!(installation_id = installation_id.to_owned()))?
        .exists(db)
        .await
}

/// List all Git connections belonging to an organization, ordered by newest first (`-created_at`).
pub async fn connections_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<GitConnection>, OrmError> {
    GitConnection::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all Git connections belonging to an organization with optional limit and offset, ordered by -created_at.
pub async fn list_connections_query(
    db: &Database,
    organization_id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<GitConnection>, i64), OrmError> {
    let mut qs = GitConnection::objects().filter(q!(organization_id = organization_id))?;
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

/// Insert a new `GitConnection` record.
pub async fn insert_connection(
    db: &Database,
    connection: GitConnection,
) -> Result<GitConnection, OrmError> {
    connection.save(db).await
}

/// Update an existing `GitConnection` record.
pub async fn update_connection(db: &Database, connection: &GitConnection) -> Result<(), OrmError> {
    connection.update(db).await
}

/// Delete a `GitConnection` by its internal primary key.
pub async fn delete_connection_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    GitConnection::objects()
        .filter(q!(id = id))?
        .delete(db)
        .await
}

/// Fetch a `WebhookDelivery` record by its unique delivery GUID.
pub async fn delivery_by_delivery_id(
    db: &Database,
    delivery_id: &str,
) -> Result<Option<WebhookDelivery>, OrmError> {
    WebhookDelivery::objects()
        .filter(q!(delivery_id = delivery_id.to_owned()))?
        .first(db)
        .await
}

/// Check if a webhook delivery GUID has already been received.
pub async fn delivery_exists(db: &Database, delivery_id: &str) -> Result<bool, OrmError> {
    WebhookDelivery::objects()
        .filter(q!(delivery_id = delivery_id.to_owned()))?
        .exists(db)
        .await
}

/// Insert a new `WebhookDelivery` record.
pub async fn insert_delivery(
    db: &Database,
    delivery: WebhookDelivery,
) -> Result<WebhookDelivery, OrmError> {
    delivery.save(db).await
}

/// Update the processing status of a `WebhookDelivery` record.
pub async fn update_delivery_status(db: &Database, id: i64, status: &str) -> Result<u64, OrmError> {
    WebhookDelivery::objects()
        .filter(q!(id = id))?
        .update(db, vec![("status", status.to_string().into_set_expr())])
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

/// Look up an organization summary by its public UUID.
pub async fn organization_summary_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<OrganizationSummary>, OrmError> {
    let found = crate::apps::organizations::models::Organization::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await?;
    Ok(found.map(|o| OrganizationSummary {
        id: o.id,
        public_id: o.public_id,
    }))
}
