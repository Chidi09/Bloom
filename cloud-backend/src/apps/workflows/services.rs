//! Business logic, domain rules, state transitions, and approval gates for `workflows`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{WorkflowApproveRequest, WorkflowCreateRequest, WorkflowRunCreateRequest};
use super::errors::WorkflowError;
use super::models::{Workflow, WorkflowRun, WorkflowRunStep};
use super::permissions::OrganizationRole;
use super::repositories::{self};
use crate::infra::queue::{Job, JobQueue};

/// Valid workflow run lifecycle statuses.
pub const VALID_RUN_STATUSES: &[&str] = &[
    "pending",
    "running",
    "blocked",
    "success",
    "failed",
    "cancelled",
];

/// Valid workflow run step lifecycle statuses.
pub const VALID_STEP_STATUSES: &[&str] = &[
    "pending",
    "running",
    "blocked",
    "completed",
    "failed",
    "skipped",
];

/// Step kinds a YAML workflow definition may declare.
///
/// An authored definition naming anything outside this set is rejected at parse time rather
/// than stored and discovered at run time.
pub const VALID_STEP_KINDS: &[&str] = &[
    "test",
    "build",
    "deploy_preview",
    "approval_gate",
    "deploy_production",
    "custom",
];

/// Returns `true` when `from -> to` is a legal workflow run status transition.
///
/// # Workflow Run Transition Matrix Rationale
/// - `pending`: Initial state upon creation before execution starts. Can transition to
///   `running` (execution begins), `blocked` (halted immediately before execution at a gate),
///   or `cancelled` (aborted by user/system before starting).
/// - `running`: Execution in progress. Can transition to `blocked` (halted at an approval gate),
///   `success` (all steps completed successfully), `failed` (a step failed), or `cancelled`
///   (user cancelled the in-flight run).
/// - `blocked`: Execution halted waiting for Release Manager approval at an approval gate.
///   Can transition to `running` (approved by Release Manager), `failed` (rejected by Release Manager),
///   or `cancelled` (user cancelled the waiting run).
/// - `success`: Terminal absorbing state. All workflow jobs finished successfully. No transitions out.
/// - `failed`: Terminal absorbing state. A job failed or an approval was rejected. No transitions out.
/// - `cancelled`: Terminal absorbing state. Run aborted. No transitions out.
pub fn can_run_transition(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("pending", "running")
            | ("pending", "blocked")
            | ("pending", "cancelled")
            | ("running", "blocked")
            | ("running", "success")
            | ("running", "failed")
            | ("running", "cancelled")
            | ("blocked", "running")
            | ("blocked", "failed")
            | ("blocked", "cancelled")
    )
}

/// Returns `true` when `from -> to` is a legal workflow run step status transition.
///
/// # Step Status Transition Matrix Rationale
/// - `pending`: Initial state. Can transition to `running` (job begins), `blocked` (approval gate reached),
///   or `skipped` (prior step failed or skipped).
/// - `running`: Active execution. Can transition to `completed` (success), `failed` (error),
///   or `skipped`.
/// - `blocked`: Approval gate waiting for decision. Can transition to `completed` (approved),
///   `failed` (rejected), or `skipped`.
/// - `completed`: Terminal absorbing state for a successful step.
/// - `failed`: Terminal absorbing state for a failed step.
/// - `skipped`: Terminal absorbing state for an unexecuted step.
pub fn can_step_transition(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("pending", "running")
            | ("pending", "blocked")
            | ("pending", "skipped")
            | ("running", "completed")
            | ("running", "failed")
            | ("running", "skipped")
            | ("blocked", "completed")
            | ("blocked", "failed")
            | ("blocked", "skipped")
    )
}

/// Emits an event to the events log.
///
/// Delegates to `crate::apps::events::emit`, which swallows and logs failures.
pub async fn emit_event(
    db: &Database,
    event_type: &str,
    organization_id: Option<i64>,
    project_id: Option<i64>,
    app_id: Option<i64>,
    actor_id: Option<i64>,
    payload: serde_json::Value,
) {
    crate::apps::events::emit(
        db,
        event_type,
        organization_id,
        project_id,
        app_id,
        actor_id,
        payload,
    )
    .await;
}

/// Synthesized step template parsed from a workflow definition.
#[derive(Debug, Clone)]
pub struct WorkflowStepTemplate {
    /// Step order index (1-indexed).
    pub step_order: i64,
    /// Step name.
    pub name: String,
    /// Step kind (e.g. `test`, `build`, `deploy_preview`, `approval_gate`, `deploy_production`, `custom`).
    pub step_kind: String,
    /// Whether this step requires manual approval.
    pub requires_approval: bool,
    /// Additional JSON metadata for the step.
    pub metadata: String,
}

/// One step as authored in a YAML workflow definition.
///
/// `order` is optional in the document: steps run in the order they are written, and an
/// explicit `order` is only needed to override that.
#[derive(Debug, Clone, serde::Deserialize)]
pub struct WorkflowDefinitionStep {
    /// Display name of the step.
    pub name: String,
    /// Step kind. Defaults to `custom` when the document omits it.
    #[serde(default = "default_step_kind", alias = "kind")]
    pub step_kind: String,
    /// Whether the step halts the run pending manual approval.
    #[serde(default, alias = "approval")]
    pub requires_approval: bool,
    /// Free-form step configuration, carried through as JSON.
    #[serde(default)]
    pub metadata: Option<serde_json::Value>,
    /// Explicit 1-based ordering, overriding document order when present.
    #[serde(default)]
    pub order: Option<i64>,
}

/// Default `step_kind` for a step that does not declare one.
fn default_step_kind() -> String {
    "custom".to_string()
}

/// A workflow definition document.
#[derive(Debug, Clone, serde::Deserialize)]
pub struct WorkflowDefinition {
    /// The ordered steps of the workflow.
    pub steps: Vec<WorkflowDefinitionStep>,
}

/// Parses a YAML workflow definition into ordered step templates.
///
/// The definition is authored by the user (docs/PHASES.md Phase 6: "Workflows can be defined in
/// YAML"), so this parses the actual document. It must never fall back to a canonical
/// pipeline when parsing fails: doing so would silently run steps the author did not write,
/// including skipping an approval gate they did declare.
///
/// YAML is parsed with `serde_norway`, the maintained fork of the deprecated `serde_yaml`.
pub fn parse_workflow_definition(
    definition: &str,
) -> Result<Vec<WorkflowStepTemplate>, WorkflowError> {
    if definition.trim().is_empty() {
        return Err(WorkflowError::ValidationError(
            "Workflow definition cannot be empty.".to_string(),
        ));
    }

    let parsed: WorkflowDefinition = serde_norway::from_str(definition).map_err(|e| {
        WorkflowError::ValidationError(format!("Workflow definition is not valid YAML: {e}"))
    })?;

    if parsed.steps.is_empty() {
        return Err(WorkflowError::ValidationError(
            "Workflow definition must declare at least one step.".to_string(),
        ));
    }

    let mut templates = Vec::with_capacity(parsed.steps.len());
    for (index, step) in parsed.steps.into_iter().enumerate() {
        let name = step.name.trim().to_string();
        if name.is_empty() {
            return Err(WorkflowError::ValidationError(
                "Every workflow step must have a non-empty name.".to_string(),
            ));
        }

        let step_kind = step.step_kind.trim().to_lowercase();
        if !VALID_STEP_KINDS.contains(&step_kind.as_str()) {
            return Err(WorkflowError::ValidationError(format!(
                "Invalid step kind '{step_kind}' on step '{name}'. Allowed values: {}.",
                VALID_STEP_KINDS.join(", ")
            )));
        }

        // An `approval_gate` step always requires approval, whether or not the document says
        // so — the gate is the entire purpose of that kind.
        let requires_approval = step.requires_approval || step_kind == "approval_gate";

        // Explicit `order` wins; otherwise document order, 1-based.
        let step_order = step.order.unwrap_or((index as i64) + 1);

        templates.push(WorkflowStepTemplate {
            step_order,
            name,
            step_kind,
            requires_approval,
            metadata: step
                .metadata
                .unwrap_or_else(|| serde_json::json!({}))
                .to_string(),
        });
    }

    templates.sort_by_key(|t| t.step_order);

    // Duplicate ordering would make execution order ambiguous.
    if let Some(dup) = templates
        .windows(2)
        .find(|w| w[0].step_order == w[1].step_order)
    {
        return Err(WorkflowError::ValidationError(format!(
            "Duplicate step order {} on steps '{}' and '{}'.",
            dup[0].step_order, dup[0].name, dup[1].name
        )));
    }

    Ok(templates)
}

/// Detailed workflow with resolved related public UUIDs for wire serialization.
#[derive(Debug, Clone)]
pub struct WorkflowDetail {
    /// The underlying workflow record.
    pub workflow: Workflow,
    /// External public UUID of the parent app.
    pub app_public_id: String,
    /// External public UUID of the owning organization.
    pub organization_public_id: String,
    /// External public identifier of the creator user.
    pub created_by_public_id: String,
}

/// Detailed workflow run with resolved related public UUIDs and ordered steps.
#[derive(Debug, Clone)]
pub struct WorkflowRunDetail {
    /// The underlying workflow run record.
    pub run: WorkflowRun,
    /// Ordered steps belonging to this run.
    pub steps: Vec<WorkflowRunStep>,
    /// External public UUID of the parent workflow.
    pub workflow_public_id: String,
    /// External public UUID of the owning organization.
    pub organization_public_id: String,
    /// External public identifier of the creator user.
    pub created_by_public_id: String,
    /// External public identifier of the approver user (if approved).
    pub approved_by_public_id: Option<String>,
}

/// Validate workflow name and slug.
pub fn validate_workflow_name_and_slug(name: &str, slug: &str) -> Result<(), WorkflowError> {
    let name_trimmed = name.trim();
    if name_trimmed.is_empty() {
        return Err(WorkflowError::ValidationError(
            "Workflow name cannot be empty.".to_string(),
        ));
    }
    if name_trimmed.len() > 255 {
        return Err(WorkflowError::ValidationError(
            "Workflow name exceeds 255 characters.".to_string(),
        ));
    }

    let slug_trimmed = slug.trim();
    if slug_trimmed.is_empty() {
        return Err(WorkflowError::ValidationError(
            "Workflow slug cannot be empty.".to_string(),
        ));
    }
    if slug_trimmed.len() > 64 {
        return Err(WorkflowError::ValidationError(
            "Workflow slug exceeds 64 characters.".to_string(),
        ));
    }
    if !slug_trimmed
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
    {
        return Err(WorkflowError::ValidationError(
            "Workflow slug must contain only ASCII alphanumeric characters, hyphens, or underscores."
                .to_string(),
        ));
    }
    Ok(())
}

/// Create a new workflow definition.
pub async fn create_workflow(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    req: WorkflowCreateRequest,
) -> Result<WorkflowDetail, WorkflowError> {
    validate_workflow_name_and_slug(&req.name, &req.slug)?;

    // Validate definition syntax through parse interface
    let _ = parse_workflow_definition(&req.definition)?;

    // 1. Resolve parent application and verify organization ownership.
    let app = repositories::app_by_public_id_and_org(db, &req.app_id, organization_id)
        .await?
        .ok_or(WorkflowError::AppNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(WorkflowError::OrganizationNotFound)?;

    // 2. Enforce slug uniqueness within the app.
    if let Some(_existing) =
        repositories::workflow_by_app_and_slug(db, app.id, req.slug.trim(), organization_id).await?
    {
        return Err(WorkflowError::DuplicateSlug(req.slug.trim().to_string()));
    }

    // 3. Insert Workflow record.
    let now = Utc::now();
    let workflow = Workflow {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        app_id: ForeignKey::new(app.id),
        organization_id,
        name: req.name.trim().to_string(),
        slug: req.slug.trim().to_string(),
        description: req.description.map(|d| d.trim().to_string()),
        definition: req.definition,
        is_active: req.is_active,
        created_by_id: user_id,
        created_at: now,
        updated_at: now,
    };

    let saved_workflow = repositories::insert_workflow(db, workflow).await?;

    // 4. Emit `workflow.created` event per docs/events.md.
    emit_event(
        db,
        "workflow.created",
        Some(organization_id),
        Some(app.project_id),
        Some(app.id),
        Some(user_id),
        serde_json::json!({
            "workflow_id": saved_workflow.public_id,
            "app_id": app.public_id,
        }),
    )
    .await;

    let user_pub_id = repositories::user_public_id_by_id(db, user_id)
        .await?
        .unwrap_or_else(|| user_id.to_string());

    Ok(WorkflowDetail {
        workflow: saved_workflow,
        app_public_id: app.public_id,
        organization_public_id: org.public_id,
        created_by_public_id: user_pub_id,
    })
}

/// Retrieve a workflow by public UUID within an organization.
pub async fn get_workflow(
    db: &Database,
    organization_id: i64,
    workflow_public_id: &str,
) -> Result<WorkflowDetail, WorkflowError> {
    let workflow =
        repositories::workflow_by_public_id_and_org(db, workflow_public_id, organization_id)
            .await?
            .ok_or(WorkflowError::WorkflowNotFound)?;

    let app = repositories::app_summary_by_id(db, workflow.app_id.id)
        .await?
        .ok_or(WorkflowError::AppNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(WorkflowError::OrganizationNotFound)?;

    let user_pub_id = repositories::user_public_id_by_id(db, workflow.created_by_id)
        .await?
        .unwrap_or_else(|| workflow.created_by_id.to_string());

    Ok(WorkflowDetail {
        workflow,
        app_public_id: app.public_id,
        organization_public_id: org.public_id,
        created_by_public_id: user_pub_id,
    })
}

/// List all workflows in an organization, optionally filtered by application.
pub async fn list_workflows(
    db: &Database,
    organization_id: i64,
    app_public_id: Option<&str>,
) -> Result<Vec<WorkflowDetail>, WorkflowError> {
    let workflows = if let Some(app_pub_id) = app_public_id {
        let app = repositories::app_by_public_id_and_org(db, app_pub_id, organization_id)
            .await?
            .ok_or(WorkflowError::AppNotFound)?;
        repositories::workflows_for_app(db, app.id, organization_id).await?
    } else {
        repositories::workflows_for_organization(db, organization_id).await?
    };

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(WorkflowError::OrganizationNotFound)?;

    let mut results = Vec::with_capacity(workflows.len());
    for w in workflows {
        let app = repositories::app_summary_by_id(db, w.app_id.id)
            .await?
            .ok_or(WorkflowError::AppNotFound)?;

        let user_pub_id = repositories::user_public_id_by_id(db, w.created_by_id)
            .await?
            .unwrap_or_else(|| w.created_by_id.to_string());

        results.push(WorkflowDetail {
            workflow: w,
            app_public_id: app.public_id,
            organization_public_id: org.public_id.clone(),
            created_by_public_id: user_pub_id,
        });
    }

    Ok(results)
}

/// Trigger and enqueue a new workflow execution run.
pub async fn create_workflow_run(
    db: &Database,
    queue: Option<&JobQueue>,
    organization_id: i64,
    user_id: i64,
    workflow_public_id: &str,
    req: WorkflowRunCreateRequest,
) -> Result<WorkflowRunDetail, WorkflowError> {
    let workflow =
        repositories::workflow_by_public_id_and_org(db, workflow_public_id, organization_id)
            .await?
            .ok_or(WorkflowError::WorkflowNotFound)?;

    let app = repositories::app_summary_by_id(db, workflow.app_id.id)
        .await?
        .ok_or(WorkflowError::AppNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(WorkflowError::OrganizationNotFound)?;

    let git_branch = req
        .git_branch
        .as_deref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .unwrap_or(&app.default_branch)
        .to_string();

    let git_ref = req
        .git_ref
        .as_deref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .unwrap_or(&git_branch)
        .to_string();

    let git_commit = req
        .git_commit
        .as_deref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_default();

    let now = Utc::now();
    let step_templates = parse_workflow_definition(&workflow.definition)?;

    // 1. Insert WorkflowRun record with status = "running"
    let run = WorkflowRun {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        workflow_id: ForeignKey::new(workflow.id),
        organization_id,
        git_commit,
        git_branch,
        git_ref,
        status: "running".to_string(),
        trigger_event: req.trigger_event,
        started_at: Some(now),
        finished_at: None,
        approved_by_id: None,
        approved_at: None,
        metadata: "{}".to_string(),
        created_by_id: user_id,
        created_at: now,
        updated_at: now,
    };

    let saved_run = repositories::insert_workflow_run(db, run).await?;

    // 2. Insert ordered WorkflowRunStep records
    let mut saved_steps = Vec::with_capacity(step_templates.len());
    for tmpl in step_templates {
        let step = WorkflowRunStep {
            id: 0,
            public_id: Uuid::new_v4().to_string(),
            run_id: ForeignKey::new(saved_run.id),
            step_order: tmpl.step_order,
            name: tmpl.name,
            step_kind: tmpl.step_kind,
            status: if tmpl.step_order == 1 {
                "running".to_string()
            } else {
                "pending".to_string()
            },
            requires_approval: tmpl.requires_approval,
            started_at: if tmpl.step_order == 1 {
                Some(now)
            } else {
                None
            },
            finished_at: None,
            log_snippet: None,
            metadata: tmpl.metadata,
            created_at: now,
        };
        let s = repositories::insert_workflow_run_step(db, step).await?;
        saved_steps.push(s);
    }

    // 3. Emit `workflowrun.started` event per docs/events.md
    emit_event(
        db,
        "workflowrun.started",
        Some(organization_id),
        Some(app.project_id),
        Some(app.id),
        Some(user_id),
        serde_json::json!({
            "run_id": saved_run.public_id,
            "workflow_id": workflow.public_id,
        }),
    )
    .await;

    // 4. Emit `workflowrun.step.started` for the first step
    if let Some(first_step) = saved_steps.first() {
        emit_event(
            db,
            "workflowrun.step.started",
            Some(organization_id),
            Some(app.project_id),
            Some(app.id),
            Some(user_id),
            serde_json::json!({
                "run_id": saved_run.public_id,
                "step_id": first_step.public_id,
                "step_name": first_step.name,
            }),
        )
        .await;
    }

    // 5. If queue is provided, enqueue build job for the initial step
    if let Some(q) = queue {
        let job = Job::Build {
            build_id: saved_run.public_id.clone(),
            organization_id: org.public_id.clone(),
            project_id: app.project_id.to_string(),
            app_id: app.public_id.clone(),
            environment_id: String::new(),
            git_commit: saved_run.git_commit.clone(),
            platform: "all".to_string(),
            build_profile: "release".to_string(),
        };
        let _ = q.push(job).await;
    }

    let user_pub_id = repositories::user_public_id_by_id(db, user_id)
        .await?
        .unwrap_or_else(|| user_id.to_string());

    Ok(WorkflowRunDetail {
        run: saved_run,
        steps: saved_steps,
        workflow_public_id: workflow.public_id,
        organization_public_id: org.public_id,
        created_by_public_id: user_pub_id,
        approved_by_public_id: None,
    })
}

/// Retrieve a workflow run by public UUID within an organization.
pub async fn get_workflow_run(
    db: &Database,
    organization_id: i64,
    run_public_id: &str,
) -> Result<WorkflowRunDetail, WorkflowError> {
    let run = repositories::workflow_run_by_public_id_and_org(db, run_public_id, organization_id)
        .await?
        .ok_or(WorkflowError::WorkflowRunNotFound)?;

    let workflow = repositories::workflow_by_id(db, run.workflow_id.id)
        .await?
        .ok_or(WorkflowError::WorkflowNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(WorkflowError::OrganizationNotFound)?;

    let steps = repositories::steps_for_workflow_run(db, run.id).await?;

    let user_pub_id = repositories::user_public_id_by_id(db, run.created_by_id)
        .await?
        .unwrap_or_else(|| run.created_by_id.to_string());

    let approved_by_pub_id = match run.approved_by_id {
        Some(approver_id) => repositories::user_public_id_by_id(db, approver_id).await?,
        None => None,
    };

    Ok(WorkflowRunDetail {
        run,
        steps,
        workflow_public_id: workflow.public_id,
        organization_public_id: org.public_id,
        created_by_public_id: user_pub_id,
        approved_by_public_id: approved_by_pub_id,
    })
}

/// List all runs for a given workflow within an organization.
pub async fn list_workflow_runs(
    db: &Database,
    organization_id: i64,
    workflow_public_id: &str,
) -> Result<Vec<WorkflowRunDetail>, WorkflowError> {
    let workflow =
        repositories::workflow_by_public_id_and_org(db, workflow_public_id, organization_id)
            .await?
            .ok_or(WorkflowError::WorkflowNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(WorkflowError::OrganizationNotFound)?;

    let runs = repositories::workflow_runs_for_workflow(db, workflow.id, organization_id).await?;

    let mut results = Vec::with_capacity(runs.len());
    for r in runs {
        let steps = repositories::steps_for_workflow_run(db, r.id).await?;
        let user_pub_id = repositories::user_public_id_by_id(db, r.created_by_id)
            .await?
            .unwrap_or_else(|| r.created_by_id.to_string());

        let approved_by_pub_id = match r.approved_by_id {
            Some(approver_id) => repositories::user_public_id_by_id(db, approver_id).await?,
            None => None,
        };

        results.push(WorkflowRunDetail {
            run: r,
            steps,
            workflow_public_id: workflow.public_id.clone(),
            organization_public_id: org.public_id.clone(),
            created_by_public_id: user_pub_id,
            approved_by_public_id: approved_by_pub_id,
        });
    }

    Ok(results)
}

/// Approve or reject a workflow run waiting at an approval gate.
///
/// # Approval Gate Requirements & Domain Rules:
/// 1. Requires `OrganizationRole::ReleaseManager` or above.
/// 2. The run MUST be halted at an approval gate (i.e. `status == "blocked"`).
/// 3. Cannot re-decide an already approved or rejected run (`GateAlreadyDecided`).
/// 4. Approving records WHO approved (`approved_by_id`) and WHEN (`approved_at`),
///    marks the approval gate step as `completed`, unblocks the run back to `running`,
///    and advances execution to the next pending step.
/// 5. Rejecting marks the approval gate step as `failed`, marks the entire run as `failed`,
///    and emits `workflowrun.completed` with `status: "failed"`.
pub async fn approve_workflow_run(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    user_role: OrganizationRole,
    run_public_id: &str,
    req: WorkflowApproveRequest,
) -> Result<WorkflowRunDetail, WorkflowError> {
    // 1. Role requirement: Release Manager or above
    if user_role < OrganizationRole::ReleaseManager {
        return Err(WorkflowError::Forbidden);
    }

    let mut run =
        repositories::workflow_run_by_public_id_and_org(db, run_public_id, organization_id)
            .await?
            .ok_or(WorkflowError::WorkflowRunNotFound)?;

    let workflow = repositories::workflow_by_id(db, run.workflow_id.id)
        .await?
        .ok_or(WorkflowError::WorkflowNotFound)?;

    let app = repositories::app_summary_by_id(db, workflow.app_id.id)
        .await?
        .ok_or(WorkflowError::AppNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(WorkflowError::OrganizationNotFound)?;

    // 2. Prevent re-deciding already decided runs
    if run.approved_at.is_some()
        || matches!(run.status.as_str(), "success" | "failed" | "cancelled")
    {
        return Err(WorkflowError::GateAlreadyDecided);
    }

    // 3. Must be in blocked status waiting at gate
    if run.status != "blocked" {
        return Err(WorkflowError::InvalidStatus(format!(
            "Workflow run must be in 'blocked' status at an approval gate to decide; current status is '{}'",
            run.status
        )));
    }

    let mut steps = repositories::steps_for_workflow_run(db, run.id).await?;
    let now = Utc::now();

    // Find the gate step that is blocked/requires approval
    let gate_idx = steps
        .iter()
        .position(|s| {
            s.requires_approval
                && (s.status == "blocked" || s.status == "running" || s.status == "pending")
        })
        .ok_or_else(|| {
            WorkflowError::ValidationError(
                "No active approval gate step found on this run.".to_string(),
            )
        })?;

    if req.approved {
        // APPROVE:
        if !can_run_transition(&run.status, "running") {
            return Err(WorkflowError::InvalidStatus(
                "Cannot transition run from blocked to running".to_string(),
            ));
        }

        // Complete the approval step
        steps[gate_idx].status = "completed".to_string();
        steps[gate_idx].finished_at = Some(now);
        repositories::update_workflow_run_step(db, &steps[gate_idx]).await?;

        emit_event(
            db,
            "workflowrun.step.completed",
            Some(organization_id),
            Some(app.project_id),
            Some(app.id),
            Some(user_id),
            serde_json::json!({
                "run_id": run.public_id,
                "step_id": steps[gate_idx].public_id,
                "status": "completed",
            }),
        )
        .await;

        // Record approver and timestamp
        run.status = "running".to_string();
        run.approved_by_id = Some(user_id);
        run.approved_at = Some(now);
        run.updated_at = now;
        repositories::update_workflow_run(db, &run).await?;

        // Advance next pending step if available
        if let Some(next_step) = steps.get_mut(gate_idx + 1) {
            if next_step.status == "pending" {
                next_step.status = "running".to_string();
                next_step.started_at = Some(now);
                repositories::update_workflow_run_step(db, next_step).await?;

                emit_event(
                    db,
                    "workflowrun.step.started",
                    Some(organization_id),
                    Some(app.project_id),
                    Some(app.id),
                    Some(user_id),
                    serde_json::json!({
                        "run_id": run.public_id,
                        "step_id": next_step.public_id,
                        "step_name": next_step.name,
                    }),
                )
                .await;
            }
        } else {
            // No more steps: run completes
            run.status = "success".to_string();
            run.finished_at = Some(now);
            repositories::update_workflow_run(db, &run).await?;

            emit_event(
                db,
                "workflowrun.completed",
                Some(organization_id),
                Some(app.project_id),
                Some(app.id),
                Some(user_id),
                serde_json::json!({
                    "run_id": run.public_id,
                    "status": "success",
                }),
            )
            .await;
        }
    } else {
        // REJECT:
        if !can_run_transition(&run.status, "failed") {
            return Err(WorkflowError::InvalidStatus(
                "Cannot transition run from blocked to failed".to_string(),
            ));
        }

        steps[gate_idx].status = "failed".to_string();
        steps[gate_idx].finished_at = Some(now);
        steps[gate_idx].log_snippet = req.reason.clone();
        repositories::update_workflow_run_step(db, &steps[gate_idx]).await?;

        emit_event(
            db,
            "workflowrun.step.completed",
            Some(organization_id),
            Some(app.project_id),
            Some(app.id),
            Some(user_id),
            serde_json::json!({
                "run_id": run.public_id,
                "step_id": steps[gate_idx].public_id,
                "status": "failed",
            }),
        )
        .await;

        // Skip subsequent steps
        for future_step in steps.iter_mut().skip(gate_idx + 1) {
            if future_step.status == "pending" {
                future_step.status = "skipped".to_string();
                repositories::update_workflow_run_step(db, future_step).await?;
            }
        }

        run.status = "failed".to_string();
        run.finished_at = Some(now);
        run.updated_at = now;
        repositories::update_workflow_run(db, &run).await?;

        emit_event(
            db,
            "workflow.rejected",
            Some(organization_id),
            Some(app.project_id),
            Some(app.id),
            Some(user_id),
            serde_json::json!({
                "run_id": run.public_id,
                "workflow_id": workflow.public_id,
                "rejected_by": user_id,
                "reason": req.reason,
            }),
        )
        .await;

        emit_event(
            db,
            "workflowrun.completed",
            Some(organization_id),
            Some(app.project_id),
            Some(app.id),
            Some(user_id),
            serde_json::json!({
                "run_id": run.public_id,
                "status": "failed",
            }),
        )
        .await;
    }

    let user_pub_id = repositories::user_public_id_by_id(db, run.created_by_id)
        .await?
        .unwrap_or_else(|| run.created_by_id.to_string());

    let approved_by_pub_id = match run.approved_by_id {
        Some(approver_id) => repositories::user_public_id_by_id(db, approver_id).await?,
        None => None,
    };

    Ok(WorkflowRunDetail {
        run,
        steps,
        workflow_public_id: workflow.public_id,
        organization_public_id: org.public_id,
        created_by_public_id: user_pub_id,
        approved_by_public_id: approved_by_pub_id,
    })
}

/// Approve or reject a workflow run waiting at an approval gate and re-enqueue to the job queue.
///
/// On approval, if subsequent steps remain pending, this enqueues the run back to [`JobQueue`]
/// to resume execution at the next step without requiring a manual trigger.
pub async fn approve_and_enqueue_workflow_run(
    db: &Database,
    queue: &JobQueue,
    organization_id: i64,
    user_id: i64,
    user_role: OrganizationRole,
    run_public_id: &str,
    req: WorkflowApproveRequest,
) -> Result<WorkflowRunDetail, WorkflowError> {
    let detail =
        approve_workflow_run(db, organization_id, user_id, user_role, run_public_id, req).await?;

    if detail.run.status == "running" {
        // Resuming after an approval re-enqueues the run itself, not a build. The workflow
        // worker picks it up and continues at the first step that is not yet complete.
        let job = Job::Workflow {
            run_id: detail.run.public_id.clone(),
            organization_id: detail.organization_public_id.clone(),
            workflow_id: detail.workflow_public_id.clone(),
            environment_id: None,
        };
        let _ = queue
            .push(job)
            .await
            .map_err(|e| WorkflowError::QueueError(e.to_string()))?;
    }

    Ok(detail)
}
