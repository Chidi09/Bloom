//! Database queries and persistence operations for the `webhosting` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::{CustomDomain, WebDeployment};

/// Fetch a `WebDeployment` by its internal primary key.
pub async fn deployment_by_id(db: &Database, id: i64) -> Result<Option<WebDeployment>, OrmError> {
    WebDeployment::objects()
        .filter(q!(id = id))?
        .first(db)
        .await
}

/// Fetch a `WebDeployment` by its external public UUID.
pub async fn deployment_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<WebDeployment>, OrmError> {
    WebDeployment::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `WebDeployment` by its external public UUID within a specific organization.
pub async fn deployment_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<WebDeployment>, OrmError> {
    WebDeployment::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// List deployments for a specific app within an organization, newest first.
pub async fn deployments_for_app(
    db: &Database,
    app_id: i64,
    organization_id: i64,
) -> Result<Vec<WebDeployment>, OrmError> {
    WebDeployment::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all web deployments in an organization, newest first.
pub async fn deployments_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<WebDeployment>, OrmError> {
    WebDeployment::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// Optional SQL-level filters for a web deployment listing.
///
/// These travel together through both the service and repository layers, so they are grouped
/// rather than threaded as four parallel `Option` arguments that are easy to transpose at a
/// call site (`target` and `status` are both `Option<&str>`).
#[derive(Debug, Default, Clone, Copy)]
pub struct WebDeploymentFilters<'a> {
    /// Restrict to a single app by internal primary key.
    pub app_id: Option<i64>,
    /// Restrict to a single environment by internal primary key.
    pub environment_id: Option<i64>,
    /// Restrict to a deployment target (e.g. `production`).
    pub target: Option<&'a str>,
    /// Restrict to a deployment status (e.g. `live`).
    pub status: Option<&'a str>,
}

/// List web deployments with optional filters, limit, and offset, ordered by -created_at.
pub async fn list_web_deployments_query(
    db: &Database,
    organization_id: i64,
    filters: WebDeploymentFilters<'_>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<WebDeployment>, i64), OrmError> {
    let mut qs = WebDeployment::objects().filter(q!(organization_id = organization_id))?;
    if let Some(aid) = filters.app_id {
        qs = qs.filter(q!(app_id = aid))?;
    }
    if let Some(eid) = filters.environment_id {
        qs = qs.filter(q!(environment_id = eid))?;
    }
    if let Some(t) = filters.target {
        qs = qs.filter(q!(target = t.to_owned()))?;
    }
    if let Some(s) = filters.status {
        qs = qs.filter(q!(status = s.to_owned()))?;
    }
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

/// Look up the previous successful deployment for an app and target to restore on rollback.
///
/// Finds the most recent deployment for the given `app_id` and `target` whose primary key
/// differs from `current_id` and whose status was `live` or `rolled_back`.
pub async fn previous_deployment_for_app_and_target(
    db: &Database,
    app_id: i64,
    organization_id: i64,
    target: &str,
    current_id: i64,
) -> Result<Option<WebDeployment>, OrmError> {
    let all = WebDeployment::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(organization_id = organization_id))?
        .filter(q!(target = target.to_owned()))?
        .order_by("-created_at")?
        .all(db)
        .await?;

    let prev = all
        .into_iter()
        .find(|d| d.id != current_id && (d.status == "live" || d.status == "rolled_back"));

    Ok(prev)
}

/// Insert a new `WebDeployment` record.
pub async fn insert_deployment(
    db: &Database,
    deployment: WebDeployment,
) -> Result<WebDeployment, OrmError> {
    deployment.save(db).await
}

/// Insert a web deployment and immediately activate it to `live` status in a single transaction.
pub async fn insert_and_activate_deployment_atomically(
    db: &Database,
    deployment: WebDeployment,
) -> Result<WebDeployment, OrmError> {
    use djangors_db::DbExecutor;
    use djangors_orm::expr::IntoSetExpr;
    use djangors_orm::QuerySet;

    db.transaction_conn(|conn| {
        Box::pin(async move {
            let mut dep = deployment;
            let pks =
                QuerySet::<WebDeployment>::bulk_create(conn.conn(), std::slice::from_ref(&dep))
                    .await?;
            let dep_id = pks.first().copied().unwrap_or(0);
            dep.id = dep_id;

            if dep.status == "deploying" {
                dep.status = "live".to_string();
                WebDeployment::objects()
                    .filter(q!(id = dep_id))?
                    .update(
                        conn.conn(),
                        vec![("status", "live".to_string().into_set_expr())],
                    )
                    .await?;
            }

            Ok::<WebDeployment, OrmError>(dep)
        })
    })
    .await
    .map_err(|e| OrmError::InvalidQuery(e.to_string()))
}

/// Rollback the current deployment and activate the previous deployment in a single transaction.
pub async fn rollback_deployment_pair_atomically(
    db: &Database,
    current_id: i64,
    previous_id: i64,
) -> Result<(), OrmError> {
    use djangors_db::DbExecutor;
    use djangors_orm::expr::IntoSetExpr;

    db.transaction_conn(|conn| {
        Box::pin(async move {
            WebDeployment::objects()
                .filter(q!(id = current_id))?
                .update(
                    conn.conn(),
                    vec![("status", "rolled_back".to_string().into_set_expr())],
                )
                .await?;

            WebDeployment::objects()
                .filter(q!(id = previous_id))?
                .update(
                    conn.conn(),
                    vec![("status", "live".to_string().into_set_expr())],
                )
                .await?;

            Ok::<(), OrmError>(())
        })
    })
    .await
    .map_err(|e| OrmError::InvalidQuery(e.to_string()))
}

/// Update an existing `WebDeployment` record.
pub async fn update_deployment(db: &Database, deployment: &WebDeployment) -> Result<(), OrmError> {
    deployment.update(db).await
}

/// Fetch a `CustomDomain` by its internal primary key.
pub async fn custom_domain_by_id(db: &Database, id: i64) -> Result<Option<CustomDomain>, OrmError> {
    CustomDomain::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `CustomDomain` by its external public UUID.
pub async fn custom_domain_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<CustomDomain>, OrmError> {
    CustomDomain::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `CustomDomain` by its external public UUID within an organization.
pub async fn custom_domain_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<CustomDomain>, OrmError> {
    CustomDomain::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch a `CustomDomain` by app primary key and domain string.
pub async fn custom_domain_by_app_and_domain(
    db: &Database,
    app_id: i64,
    domain: &str,
) -> Result<Option<CustomDomain>, OrmError> {
    CustomDomain::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(domain = domain.to_owned()))?
        .first(db)
        .await
}

/// List custom domains belonging to an app within an organization, newest first.
pub async fn custom_domains_for_app(
    db: &Database,
    app_id: i64,
    organization_id: i64,
) -> Result<Vec<CustomDomain>, OrmError> {
    CustomDomain::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all custom domains belonging to an organization, newest first.
pub async fn custom_domains_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<CustomDomain>, OrmError> {
    CustomDomain::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List custom domains with optional app filter, limit, and offset, ordered by -created_at.
pub async fn list_custom_domains_query(
    db: &Database,
    organization_id: i64,
    app_id: Option<i64>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<CustomDomain>, i64), OrmError> {
    let mut qs = CustomDomain::objects().filter(q!(organization_id = organization_id))?;
    if let Some(aid) = app_id {
        qs = qs.filter(q!(app_id = aid))?;
    }
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

/// Insert a new `CustomDomain` record.
pub async fn insert_custom_domain(
    db: &Database,
    domain: CustomDomain,
) -> Result<CustomDomain, OrmError> {
    domain.save(db).await
}

/// Update an existing `CustomDomain` record.
pub async fn update_custom_domain(db: &Database, domain: &CustomDomain) -> Result<(), OrmError> {
    domain.update(db).await
}

/// Delete a `CustomDomain` record by internal primary key.
pub async fn delete_custom_domain_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    CustomDomain::objects()
        .filter(q!(id = id))?
        .delete(db)
        .await
}

// ---------------------------------------------------------------------------
// External entity lookups (organizations, apps, projects, environments,
// artifacts, releases) via each owning app's public model through the ORM —
// never raw SQL against another app's table.
// ---------------------------------------------------------------------------

/// Resolved summary for an organization entity.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
}

/// Resolved summary for an application entity.
#[derive(Debug, Clone)]
pub struct AppSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
    /// Human-readable app name.
    pub name: String,
    /// URL slug.
    pub slug: String,
    /// Default branch name.
    pub default_branch: String,
    /// Internal primary key of the parent project.
    pub project_id: i64,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
}

/// Resolved summary for a project entity.
#[derive(Debug, Clone)]
pub struct ProjectSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
    /// Human-readable project name.
    pub name: String,
    /// URL slug.
    pub slug: String,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
}

/// Resolved summary for an environment entity.
#[derive(Debug, Clone)]
pub struct EnvironmentSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
    /// Internal primary key of the parent app.
    pub app_id: i64,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
    /// Human-readable environment name.
    pub name: String,
    /// Environment URL slug.
    pub slug: String,
}

/// Resolved summary for an artifact entity.
#[derive(Debug, Clone)]
pub struct ArtifactSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
    /// Internal primary key of the parent build.
    pub build_id: i64,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
    /// Target platform.
    pub platform: String,
    /// Artifact kind (`web_bundle`, etc.).
    pub kind: String,
    /// Canonical storage key.
    pub storage_key: String,
}

/// Resolved summary for a release entity.
#[derive(Debug, Clone)]
pub struct ReleaseSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
    /// Internal primary key of the parent app.
    pub app_id: i64,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
    /// Semantic version string.
    pub version: String,
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

/// Look up an app summary by its internal primary key.
pub async fn app_summary_by_id(db: &Database, app_id: i64) -> Result<Option<AppSummary>, OrmError> {
    let found = crate::apps::apps::models::App::objects()
        .filter(q!(id = app_id))?
        .first(db)
        .await?;
    Ok(found.map(|a| AppSummary {
        id: a.id,
        public_id: a.public_id,
        name: a.name,
        slug: a.slug,
        default_branch: a.default_branch,
        project_id: a.project_id,
        organization_id: a.organization_id,
    }))
}

/// Look up an app summary by its public UUID within an organization.
pub async fn app_summary_by_public_id_and_org(
    db: &Database,
    app_public_id: &str,
    organization_id: i64,
) -> Result<Option<AppSummary>, OrmError> {
    let found = crate::apps::apps::models::App::objects()
        .filter(q!(public_id = app_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(|a| AppSummary {
        id: a.id,
        public_id: a.public_id,
        name: a.name,
        slug: a.slug,
        default_branch: a.default_branch,
        project_id: a.project_id,
        organization_id: a.organization_id,
    }))
}

/// Look up a project summary by its internal primary key.
pub async fn project_summary_by_id(
    db: &Database,
    project_id: i64,
) -> Result<Option<ProjectSummary>, OrmError> {
    let found = crate::apps::projects::models::Project::objects()
        .filter(q!(id = project_id))?
        .first(db)
        .await?;
    Ok(found.map(|p| ProjectSummary {
        id: p.id,
        public_id: p.public_id,
        name: p.name,
        slug: p.slug,
        organization_id: p.organization_id.id,
    }))
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
    Ok(found.map(|e| EnvironmentSummary {
        id: e.id,
        public_id: e.public_id,
        app_id: e.app_id,
        organization_id: e.organization_id,
        name: e.name,
        slug: e.slug,
    }))
}

/// Look up an environment summary by its public UUID within an organization.
pub async fn environment_summary_by_public_id_and_org(
    db: &Database,
    environment_public_id: &str,
    organization_id: i64,
) -> Result<Option<EnvironmentSummary>, OrmError> {
    let found = crate::apps::environments::models::Environment::objects()
        .filter(q!(public_id = environment_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(|e| EnvironmentSummary {
        id: e.id,
        public_id: e.public_id,
        app_id: e.app_id,
        organization_id: e.organization_id,
        name: e.name,
        slug: e.slug,
    }))
}

/// Look up an artifact summary by its internal primary key.
pub async fn artifact_summary_by_id(
    db: &Database,
    artifact_id: i64,
) -> Result<Option<ArtifactSummary>, OrmError> {
    let found = crate::apps::artifacts::models::Artifact::objects()
        .filter(q!(id = artifact_id))?
        .first(db)
        .await?;
    Ok(found.map(|art| ArtifactSummary {
        id: art.id,
        public_id: art.public_id,
        build_id: art.build_id,
        organization_id: art.organization_id,
        platform: art.platform,
        kind: art.kind,
        storage_key: art.storage_key,
    }))
}

/// Look up an artifact summary by its public UUID within an organization.
pub async fn artifact_summary_by_public_id_and_org(
    db: &Database,
    artifact_public_id: &str,
    organization_id: i64,
) -> Result<Option<ArtifactSummary>, OrmError> {
    let found = crate::apps::artifacts::models::Artifact::objects()
        .filter(q!(public_id = artifact_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(|art| ArtifactSummary {
        id: art.id,
        public_id: art.public_id,
        build_id: art.build_id,
        organization_id: art.organization_id,
        platform: art.platform,
        kind: art.kind,
        storage_key: art.storage_key,
    }))
}

/// Project a `Release` model onto the local summary shape.
fn release_summary(r: crate::apps::releases::models::Release) -> ReleaseSummary {
    ReleaseSummary {
        id: r.id,
        public_id: r.public_id,
        app_id: r.app_id.id,
        organization_id: r.organization_id,
        version: r.version,
    }
}

/// Look up a release summary by its internal primary key.
pub async fn release_summary_by_id(
    db: &Database,
    release_id: i64,
) -> Result<Option<ReleaseSummary>, OrmError> {
    let found = crate::apps::releases::models::Release::objects()
        .filter(q!(id = release_id))?
        .first(db)
        .await?;
    Ok(found.map(release_summary))
}

/// Look up a release summary by its public UUID within an organization.
pub async fn release_summary_by_public_id_and_org(
    db: &Database,
    release_public_id: &str,
    organization_id: i64,
) -> Result<Option<ReleaseSummary>, OrmError> {
    let found = crate::apps::releases::models::Release::objects()
        .filter(q!(public_id = release_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(release_summary))
}

/// Look up multiple app summaries by internal primary keys in one batch.
pub async fn app_summaries_by_ids(
    db: &Database,
    app_ids: &[i64],
) -> Result<std::collections::HashMap<i64, AppSummary>, OrmError> {
    if app_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let apps = crate::apps::apps::models::App::objects()
        .filter(q!(id__in = app_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(apps.len());
    for a in apps {
        map.insert(
            a.id,
            AppSummary {
                id: a.id,
                public_id: a.public_id,
                name: a.name,
                slug: a.slug,
                default_branch: a.default_branch,
                project_id: a.project_id,
                organization_id: a.organization_id,
            },
        );
    }
    Ok(map)
}

/// Look up multiple environment summaries by internal primary keys in one batch.
pub async fn environment_summaries_by_ids(
    db: &Database,
    env_ids: &[i64],
) -> Result<std::collections::HashMap<i64, EnvironmentSummary>, OrmError> {
    if env_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let envs = crate::apps::environments::models::Environment::objects()
        .filter(q!(id__in = env_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(envs.len());
    for e in envs {
        map.insert(
            e.id,
            EnvironmentSummary {
                id: e.id,
                public_id: e.public_id,
                app_id: e.app_id,
                organization_id: e.organization_id,
                name: e.name,
                slug: e.slug,
            },
        );
    }
    Ok(map)
}

/// Look up multiple release summaries by internal primary keys in one batch.
pub async fn release_summaries_by_ids(
    db: &Database,
    release_ids: &[i64],
) -> Result<std::collections::HashMap<i64, ReleaseSummary>, OrmError> {
    if release_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let rels = crate::apps::releases::models::Release::objects()
        .filter(q!(id__in = release_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(rels.len());
    for r in rels {
        map.insert(r.id, release_summary(r));
    }
    Ok(map)
}

/// Look up multiple project summaries by internal primary keys in one batch.
pub async fn project_summaries_by_ids(
    db: &Database,
    project_ids: &[i64],
) -> Result<std::collections::HashMap<i64, ProjectSummary>, OrmError> {
    if project_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let projs = crate::apps::projects::models::Project::objects()
        .filter(q!(id__in = project_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(projs.len());
    for p in projs {
        map.insert(
            p.id,
            ProjectSummary {
                id: p.id,
                public_id: p.public_id,
                name: p.name,
                slug: p.slug,
                organization_id: p.organization_id.id,
            },
        );
    }
    Ok(map)
}

/// Look up multiple user profile public IDs by user internal IDs in one batch.
pub async fn user_public_ids_by_ids(
    db: &Database,
    user_ids: &[i64],
) -> Result<std::collections::HashMap<i64, String>, OrmError> {
    if user_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let profiles = crate::apps::accounts::models::UserProfile::objects()
        .filter(q!(user_id__in = user_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(profiles.len());
    for p in profiles {
        map.insert(p.user_id, p.public_id);
    }
    Ok(map)
}
