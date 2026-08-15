//! Database access and QuerySet operations for the `projects` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::Project;

/// Fetch a `Project` by internal primary key.
pub async fn project_by_id(db: &Database, id: i64) -> Result<Option<Project>, OrmError> {
    Project::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `Project` by its public UUID identifier.
pub async fn project_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<Project>, OrmError> {
    Project::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `Project` by public UUID and organization ID (scoped check).
pub async fn project_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Project>, OrmError> {
    Project::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch a `Project` by unique slug within an organization.
pub async fn project_by_slug_and_org(
    db: &Database,
    slug: &str,
    organization_id: i64,
) -> Result<Option<Project>, OrmError> {
    Project::objects()
        .filter(q!(organization_id = organization_id))?
        .filter(q!(slug = slug.to_owned()))?
        .first(db)
        .await
}

/// Check if a project with the given slug exists in an organization.
pub async fn project_slug_exists_in_org(
    db: &Database,
    organization_id: i64,
    slug: &str,
) -> Result<bool, OrmError> {
    Project::objects()
        .filter(q!(organization_id = organization_id))?
        .filter(q!(slug = slug.to_owned()))?
        .exists(db)
        .await
}

/// List all projects belonging to an organization, ordered by newest first (`-created_at`).
pub async fn projects_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Project>, OrmError> {
    Project::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// Insert a new `Project` record.
pub async fn insert_project(db: &Database, project: Project) -> Result<Project, OrmError> {
    project.save(db).await
}

/// Update an existing `Project` record.
pub async fn update_project(db: &Database, project: &Project) -> Result<(), OrmError> {
    project.update(db).await
}

/// Delete a `Project` by internal primary key.
pub async fn delete_project_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    Project::objects().filter(q!(id = id))?.delete(db).await
}

/// Count how many applications belong to a project.
pub async fn count_apps_in_project(db: &Database, project_id: i64) -> Result<i64, OrmError> {
    let mut conn = db.conn();
    let sql = match conn.dialect() {
        djangors_db::Dialect::Postgres => "SELECT COUNT(*) FROM apps_app WHERE project_id = $1",
        djangors_db::Dialect::Sqlite => "SELECT COUNT(*) FROM apps_app WHERE project_id = ?",
    };
    match conn
        .fetch_one(sql, &[djangors_db::BindValue::I64(project_id)])
        .await
    {
        Ok(row) => Ok(row.try_i64(0).map_err(OrmError::Query)?.unwrap_or(0)),
        Err(e) => {
            let err_str = e.to_string();
            if err_str.contains("does not exist") || err_str.contains("no such table") {
                Ok(0)
            } else {
                Err(OrmError::Query(e))
            }
        }
    }
}
