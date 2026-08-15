//! Database queries and persistence operations for the `workflows` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::{Workflow, WorkflowRun, WorkflowRunStep};

/// Fetch a `Workflow` by its internal primary key.
pub async fn workflow_by_id(db: &Database, id: i64) -> Result<Option<Workflow>, OrmError> {
    Workflow::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `Workflow` by its external public UUID within a specific organization.
pub async fn workflow_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Workflow>, OrmError> {
    Workflow::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch a `Workflow` by app primary key and slug within a specific organization.
pub async fn workflow_by_app_and_slug(
    db: &Database,
    app_id: i64,
    slug: &str,
    organization_id: i64,
) -> Result<Option<Workflow>, OrmError> {
    Workflow::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(slug = slug.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// List all workflows belonging to an application within an organization, newest first.
pub async fn workflows_for_app(
    db: &Database,
    app_id: i64,
    organization_id: i64,
) -> Result<Vec<Workflow>, OrmError> {
    Workflow::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all workflows belonging to an organization, newest first.
pub async fn workflows_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Workflow>, OrmError> {
    Workflow::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List workflows with optional app filter, limit, and offset, ordered by -created_at.
pub async fn list_workflows_query(
    db: &Database,
    organization_id: i64,
    app_id: Option<i64>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<Workflow>, i64), OrmError> {
    let mut qs = Workflow::objects().filter(q!(organization_id = organization_id))?;
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

/// Insert a new `Workflow` record.
pub async fn insert_workflow(db: &Database, workflow: Workflow) -> Result<Workflow, OrmError> {
    workflow.save(db).await
}

/// Update an existing `Workflow` record.
pub async fn update_workflow(db: &Database, workflow: &Workflow) -> Result<(), OrmError> {
    workflow.update(db).await
}

/// Fetch a `WorkflowRun` by its internal primary key.
pub async fn workflow_run_by_id(db: &Database, id: i64) -> Result<Option<WorkflowRun>, OrmError> {
    WorkflowRun::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `WorkflowRun` by its external public UUID within a specific organization.
pub async fn workflow_run_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<WorkflowRun>, OrmError> {
    WorkflowRun::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// List all runs belonging to a workflow within an organization, newest first.
pub async fn workflow_runs_for_workflow(
    db: &Database,
    workflow_id: i64,
    organization_id: i64,
) -> Result<Vec<WorkflowRun>, OrmError> {
    WorkflowRun::objects()
        .filter(q!(workflow_id = workflow_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List runs for a workflow with optional limit and offset, ordered by -created_at.
pub async fn list_workflow_runs_query(
    db: &Database,
    workflow_id: i64,
    organization_id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<WorkflowRun>, i64), OrmError> {
    let mut qs = WorkflowRun::objects()
        .filter(q!(workflow_id = workflow_id))?
        .filter(q!(organization_id = organization_id))?;
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

/// Insert a new `WorkflowRun` record.
pub async fn insert_workflow_run(db: &Database, run: WorkflowRun) -> Result<WorkflowRun, OrmError> {
    run.save(db).await
}

/// Update an existing `WorkflowRun` record.
pub async fn update_workflow_run(db: &Database, run: &WorkflowRun) -> Result<(), OrmError> {
    run.update(db).await
}

/// List all steps for a workflow run, ordered explicitly by `step_order` ascending.
pub async fn steps_for_workflow_run(
    db: &Database,
    run_id: i64,
) -> Result<Vec<WorkflowRunStep>, OrmError> {
    WorkflowRunStep::objects()
        .filter(q!(run_id = run_id))?
        .order_by("step_order")?
        .all(db)
        .await
}

/// Insert a new `WorkflowRunStep` record.
pub async fn insert_workflow_run_step(
    db: &Database,
    step: WorkflowRunStep,
) -> Result<WorkflowRunStep, OrmError> {
    step.save(db).await
}

/// Update an existing `WorkflowRunStep` record.
pub async fn update_workflow_run_step(
    db: &Database,
    step: &WorkflowRunStep,
) -> Result<(), OrmError> {
    step.update(db).await
}

// ---------------------------------------------------------------------------
// External entity lookups (apps, organizations, users, projects) projected
// onto local summary types per docs/APP_PATTERN.md / COMMON_RULES.
// ---------------------------------------------------------------------------

/// Resolved summary for an application entity.
#[derive(Debug, Clone)]
pub struct AppSummary {
    /// Internal primary key of the app.
    pub id: i64,
    /// External public UUID of the app.
    pub public_id: String,
    /// Internal primary key of the parent project.
    pub project_id: i64,
    /// Name of the app.
    pub name: String,
    /// Slug of the app.
    pub slug: String,
    /// Default Git branch of the app.
    pub default_branch: String,
}

/// Look up an app by its external public UUID within an organization.
pub async fn app_by_public_id_and_org(
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
        project_id: a.project_id,
        name: a.name,
        slug: a.slug,
        default_branch: a.default_branch,
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
        project_id: a.project_id,
        name: a.name,
        slug: a.slug,
        default_branch: a.default_branch,
    }))
}

/// Resolved summary for an organization entity.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key of the organization.
    pub id: i64,
    /// External public UUID of the organization.
    pub public_id: String,
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

/// Look up a user's external public UUID by their internal primary key (`auth_user.id`).
pub async fn user_public_id_by_id(db: &Database, user_id: i64) -> Result<Option<String>, OrmError> {
    let profile = crate::apps::accounts::models::UserProfile::objects()
        .filter(q!(user_id = user_id))?
        .first(db)
        .await?;

    Ok(profile.map(|p| p.public_id))
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
                project_id: a.project_id,
                name: a.name,
                slug: a.slug,
                default_branch: a.default_branch,
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
