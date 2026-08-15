//! Database queries and persistence operations for the `secrets` domain app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::{Secret, SecretVersion};

/// Fetch a `Secret` by its internal primary key.
pub async fn secret_by_id(db: &Database, id: i64) -> Result<Option<Secret>, OrmError> {
    Secret::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `Secret` by its external public UUID within an organization.
pub async fn secret_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Secret>, OrmError> {
    Secret::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch a `Secret` by its environment ID and key name.
pub async fn secret_by_env_and_key(
    db: &Database,
    environment_id: i64,
    key: &str,
) -> Result<Option<Secret>, OrmError> {
    Secret::objects()
        .filter(q!(environment_id = environment_id))?
        .filter(q!(key = key.to_owned()))?
        .first(db)
        .await
}

/// List all secrets belonging to an environment within an organization.
pub async fn secrets_for_environment(
    db: &Database,
    environment_id: i64,
    organization_id: i64,
) -> Result<Vec<Secret>, OrmError> {
    Secret::objects()
        .filter(q!(environment_id = environment_id))?
        .filter(q!(organization_id = organization_id))?
        .all(db)
        .await
}

/// List all secrets belonging to an organization.
pub async fn secrets_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Secret>, OrmError> {
    Secret::objects()
        .filter(q!(organization_id = organization_id))?
        .all(db)
        .await
}

/// Insert a new `Secret` record.
pub async fn insert_secret(db: &Database, secret: Secret) -> Result<Secret, OrmError> {
    secret.save(db).await
}

/// Update an existing `Secret` record.
pub async fn update_secret(db: &Database, secret: &Secret) -> Result<(), OrmError> {
    secret.update(db).await
}

/// Delete a `Secret` record by its internal primary key.
pub async fn delete_secret_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    Secret::objects().filter(q!(id = id))?.delete(db).await
}

/// Insert a new `SecretVersion` record into history.
pub async fn insert_secret_version(
    db: &Database,
    version: SecretVersion,
) -> Result<SecretVersion, OrmError> {
    version.save(db).await
}

/// Fetch a specific historical version of a secret.
pub async fn secret_version_by_secret_and_version(
    db: &Database,
    secret_id: i64,
    version: i64,
) -> Result<Option<SecretVersion>, OrmError> {
    SecretVersion::objects()
        .filter(q!(secret_id = secret_id))?
        .filter(q!(version = version))?
        .first(db)
        .await
}

/// List all historical versions for a given secret.
pub async fn secret_versions_for_secret(
    db: &Database,
    secret_id: i64,
) -> Result<Vec<SecretVersion>, OrmError> {
    SecretVersion::objects()
        .filter(q!(secret_id = secret_id))?
        .all(db)
        .await
}

// ---------------------------------------------------------------------------
// External entity lookups (environments, organizations) via SQL queries to
// decouple apps being developed in parallel.
// ---------------------------------------------------------------------------

/// Resolved summary for an environment entity.
#[derive(Debug, Clone)]
pub struct EnvironmentSummary {
    /// Internal primary key of the environment.
    pub id: i64,
    /// External public UUID of the environment.
    pub public_id: String,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
    /// Name of the environment.
    pub name: String,
    /// Slug of the environment.
    pub slug: String,
}

/// Resolved summary for an organization entity.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key of the organization.
    pub id: i64,
    /// External public UUID of the organization.
    pub public_id: String,
}

/// Look up an environment by its external public UUID within an organization.
pub async fn environment_summary_by_public_id_and_org(
    db: &Database,
    env_public_id: &str,
    organization_id: i64,
) -> Result<Option<EnvironmentSummary>, OrmError> {
    let found = crate::apps::environments::models::Environment::objects()
        .filter(q!(public_id = env_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(environment_summary))
}

/// Project an `Environment` model onto the local summary shape.
fn environment_summary(e: crate::apps::environments::models::Environment) -> EnvironmentSummary {
    EnvironmentSummary {
        id: e.id,
        public_id: e.public_id,
        organization_id: e.organization_id,
        name: e.name,
        slug: e.slug,
    }
}

/// Look up an environment summary by its internal primary key.
pub async fn environment_summary_by_id(
    db: &Database,
    environment_id: i64,
) -> Result<Option<EnvironmentSummary>, OrmError> {
    let found = crate::apps::environments::models::Environment::objects()
        .filter(q!(id = environment_id))?
        .first(db)
        .await?;
    Ok(found.map(environment_summary))
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
