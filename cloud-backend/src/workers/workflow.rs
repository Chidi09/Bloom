//! Workflow execution engine worker advancing workflow runs step-by-step.
//!
//! # Architecture & Scope
//!
//! The workflow worker claims workflow runs from the [`JobQueue`], walks their steps in `order`,
//! and drives each step kind from [`VALID_STEP_KINDS`]:
//! - `test` / `build`: creates a real build through the builds service (which enqueues it), then
//!   PARKS the run. The step is left `running`, never `completed` -- the build has not run yet.
//! - `deploy_preview` / `deploy_production`: creates a real deployment the same way, then parks.
//! - `approval_gate`: parks the run in `blocked` status and terminates worker execution immediately
//!   via `queue.ack`, releasing the worker slot without busy-waiting.
//! - `custom`: executes declared sandboxed commands via the Phase 9 [`CommandExecutor`].
//!
//! # Resumption
//!
//! When an approval gate is decided via `approve_workflow_run`, the run is unblocked and
//! re-enqueued to the [`JobQueue`] as [`Job::Workflow`], resuming at the next pending step.
//!
//! A run parked on a child build or deployment resumes the same way. NOTE: the build and
//! deploy workers do not yet re-enqueue their parent run when they reach a terminal state, so
//! that half of the resumption path is not connected. A parked run is correct but currently
//! inert until that is wired up; it is never reported as succeeded.
//!
//! # Failure Semantics
//!
//! - A failed step fails the entire run by default.
//! - A step declaring `continue_on_error: true` in its metadata is recorded as failed while
//!   allowing downstream steps to proceed.
//! - Downstream steps observe prior step outputs via [`WorkflowRunContext`].
//!
//! # Timeouts & Orphan Recovery
//!
//! Worker heartbeats via [`JobQueue::heartbeat`] ensure active claims are renewed.
//! If a worker terminates unexpectedly, its claimed job expires and is recovered via Redis `XAUTOCLAIM`
//! (or in-memory claim expiration), resuming from the first uncompleted step.
//!
//! # Concurrency Control
//!
//! At most one active run per workflow per environment executes concurrently. Newer runs remain
//! queued rather than racing.
//!
//! # Total Ack/Fail Contract
//!
//! Every claimed workflow job MUST explicitly terminate in:
//! - `queue.ack(stream_id)` on successful completion or clean parking at an approval gate.
//! - `queue.fail(stream_id, &reason)` on unrecoverable failure, updating the run record to `failed`.

use std::collections::HashMap;
use std::fmt;
use std::path::PathBuf;
use std::time::Duration;

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::{q, Model};
use serde::{Deserialize, Serialize};

use crate::apps::deployments::permissions::OrganizationRole;
use crate::apps::workflows::errors::WorkflowError;
use crate::apps::workflows::models::{WorkflowRun, WorkflowRunStep};
use crate::apps::workflows::repositories::{self, AppSummary};
use crate::apps::workflows::services::{
    can_run_transition, can_step_transition, emit_event, VALID_STEP_KINDS,
};
use crate::infra::executor::{CommandExecutor, CommandSpec, ExecutorError};
use crate::infra::queue::{Job, JobQueue, QueueError, QueuedJob};

/// Default timeout in seconds for custom command execution within a step.
pub const DEFAULT_STEP_TIMEOUT_SECS: u64 = 600;

/// Errors arising during workflow worker execution.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WorkflowWorkerError {
    /// Queue interaction error.
    Queue(String),
    /// Database or persistence error.
    Database(String),
    /// Command execution failure.
    Executor(String),
    /// Domain workflow service error.
    WorkflowService(String),
    /// Unexpected job variant passed to workflow worker.
    InvalidJobVariant(String),
    /// Workflow run record not found.
    RunNotFound(String),
    /// Workflow definition record not found.
    WorkflowNotFound(String),
    /// Concurrency limit reached for this workflow/environment.
    ConcurrencyLimit {
        /// Public UUID of the blocked run.
        run_id: String,
        /// Diagnostic reason.
        reason: String,
    },
    /// Step execution failure without `continue_on_error`.
    StepFailed {
        /// Name of the failed step.
        step_name: String,
        /// Kind of the failed step.
        step_kind: String,
        /// Detailed failure reason.
        reason: String,
    },
}

impl fmt::Display for WorkflowWorkerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            WorkflowWorkerError::Queue(msg) => write!(f, "Workflow worker queue error: {msg}"),
            WorkflowWorkerError::Database(msg) => {
                write!(f, "Workflow worker database error: {msg}")
            }
            WorkflowWorkerError::Executor(msg) => {
                write!(f, "Workflow worker command execution error: {msg}")
            }
            WorkflowWorkerError::WorkflowService(msg) => {
                write!(f, "Workflow worker service error: {msg}")
            }
            WorkflowWorkerError::InvalidJobVariant(msg) => {
                write!(f, "Invalid job variant for workflow worker: {msg}")
            }
            WorkflowWorkerError::RunNotFound(id) => {
                write!(f, "Workflow run '{id}' not found")
            }
            WorkflowWorkerError::WorkflowNotFound(id) => {
                write!(f, "Workflow definition '{id}' not found")
            }
            WorkflowWorkerError::ConcurrencyLimit { run_id, reason } => {
                write!(
                    f,
                    "Workflow run '{run_id}' cannot start due to concurrency limit: {reason}"
                )
            }
            WorkflowWorkerError::StepFailed {
                step_name,
                step_kind,
                reason,
            } => {
                write!(
                    f,
                    "Workflow step '{step_name}' ({step_kind}) failed: {reason}"
                )
            }
        }
    }
}

impl std::error::Error for WorkflowWorkerError {}

impl From<QueueError> for WorkflowWorkerError {
    fn from(err: QueueError) -> Self {
        WorkflowWorkerError::Queue(err.to_string())
    }
}

impl From<ExecutorError> for WorkflowWorkerError {
    fn from(err: ExecutorError) -> Self {
        WorkflowWorkerError::Executor(err.to_string())
    }
}

impl From<WorkflowError> for WorkflowWorkerError {
    fn from(err: WorkflowError) -> Self {
        WorkflowWorkerError::WorkflowService(err.to_string())
    }
}

impl From<djangors_orm::OrmError> for WorkflowWorkerError {
    fn from(err: djangors_orm::OrmError) -> Self {
        WorkflowWorkerError::Database(err.to_string())
    }
}

/// Output captured from an individual step execution for downstream consumption.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StepOutput {
    /// Step execution status (`completed` or `failed`).
    pub status: String,
    /// Process exit code if from a `custom` command.
    pub exit_code: Option<i32>,
    /// Stdout or summary output.
    pub stdout: Option<String>,
    /// Stderr or failure diagnostics.
    pub stderr: Option<String>,
    /// Additional JSON metadata produced by the step.
    pub metadata: serde_json::Value,
}

/// Run-scoped execution context carrying state and outputs across workflow steps.
#[derive(Debug, Clone, Default)]
pub struct WorkflowRunContext {
    /// External public UUID of the workflow run.
    pub run_id: String,
    /// External public UUID of the parent workflow.
    pub workflow_id: String,
    /// Database internal ID of the workflow run.
    pub run_db_id: i64,
    /// Database internal ID of the owning tenant organization.
    pub organization_id: i64,
    /// Git commit SHA.
    pub git_commit: String,
    /// Git branch.
    pub git_branch: String,
    /// Git ref.
    pub git_ref: String,
    /// Target environment if specified.
    pub environment: Option<String>,
    /// Artifact produced by the most recent completed build step in this run.
    ///
    /// Held as an explicit ordered field rather than scanned out of `step_outputs`: that map
    /// is keyed by step name and iterates in unspecified order, so picking "the last one"
    /// from it would choose a different artifact between runs.
    pub last_build_artifact_id: Option<String>,
    /// Step outputs keyed by step name.
    pub step_outputs: HashMap<String, StepOutput>,
}

/// Lightweight summary of a workflow run used for concurrency evaluation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkflowRunSummary {
    /// Internal primary key of the run.
    pub id: i64,
    /// Internal primary key of the parent workflow.
    pub workflow_id: i64,
    /// Current execution status.
    pub status: String,
    /// Optional environment tag.
    pub environment: Option<String>,
}

/// Dependencies injected into the workflow execution worker.
pub struct WorkflowWorkerDeps<'a> {
    /// Database connection handle.
    pub db: &'a Database,
    /// Job queue for heartbeat, ack, fail, and enqueuing child jobs.
    pub queue: &'a JobQueue,
    /// Sandboxed command executor for `custom` steps.
    pub executor: &'a dyn CommandExecutor,
}

/// Context parameters extracted from a claimed job payload.
#[derive(Debug, Clone)]
pub struct WorkflowJobContext {
    /// External public UUID of the workflow run.
    pub run_id: String,
    /// External public UUID of the owning organization.
    pub organization_id: String,
    /// Optional target environment identifier.
    pub environment_id: Option<String>,
}

/// Status a step reports when it has queued child work and the run must park.
///
/// This is deliberately not one of the persisted step statuses: it never reaches the
/// database. The run loop translates it into a `running` step and a `running` run, acks the
/// job, and returns. It exists so a step cannot accidentally be recorded as `completed`
/// when all it did was enqueue a build or a deployment.
pub const STEP_AWAITING_CHILD: &str = "awaiting_child";

/// Output summary returned by a workflow worker execution cycle.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkflowWorkerResult {
    /// Public UUID of the workflow run.
    pub run_id: String,
    /// Terminal or interim run status (`success`, `failed`, `blocked`).
    pub status: String,
    /// Number of steps completed in this execution cycle.
    pub steps_completed: usize,
    /// Whether the run was parked at an approval gate without error.
    pub parked_at_gate: bool,
}

/// Concurrency predicate evaluating whether a workflow run is permitted to execute.
///
/// # Concurrency Control Rationale (Phase 11 Deliverable 5)
/// At most one active run per workflow per environment may execute concurrently.
/// An active run is any run currently in `running` or `blocked` status.
/// If another active run exists for the same workflow and environment, the newer run must queue.
pub fn can_execute_run(
    active_runs: &[WorkflowRunSummary],
    target_workflow_id: i64,
    current_run_id: i64,
    target_env: Option<&str>,
) -> bool {
    let other_active = active_runs.iter().any(|r| {
        r.id != current_run_id
            && r.workflow_id == target_workflow_id
            && matches!(r.status.as_str(), "running" | "blocked")
            && match (r.environment.as_deref(), target_env) {
                (Some(e1), Some(e2)) => e1 == e2,
                (None, None) => true,
                _ => false,
            }
    });

    !other_active
}

/// Inspects step metadata to determine if `continue_on_error` is declared.
pub fn step_continues_on_error(metadata_json: &str) -> bool {
    if let Ok(val) = serde_json::from_str::<serde_json::Value>(metadata_json) {
        val.get("continue_on_error")
            .and_then(|v| v.as_bool())
            .or_else(|| val.get("continue-on-error").and_then(|v| v.as_bool()))
            .unwrap_or(false)
    } else {
        false
    }
}

/// Context parameters for driving an individual workflow step.
struct StepRunContext<'a> {
    step: &'a mut WorkflowRunStep,
    app_summary: &'a AppSummary,
    /// Internal organization key, needed to create the child build or deployment records.
    organization_id: i64,
    /// Internal key of the user the run is acting as, recorded as the child's creator.
    actor_user_id: i64,
}

/// Executes a claimed workflow run job with total ack/fail semantics.
///
/// Workflow:
/// 1. Validates the claimed job payload and extracts workflow run identifiers.
/// 2. Executes the workflow pipeline steps sequentially.
/// 3. If an approval gate is encountered, parks the run in `blocked` status and invokes `queue.ack`,
///    freeing the worker thread immediately without busy-waiting.
/// 4. On successful completion of all steps, marks the run as `success` and invokes `queue.ack`.
/// 5. On unrecoverable error, updates run and steps to `failed` and invokes `queue.fail`.
pub async fn run_workflow_job(
    deps: WorkflowWorkerDeps<'_>,
    consumer_name: &str,
    queued_job: QueuedJob,
) -> Result<WorkflowWorkerResult, WorkflowWorkerError> {
    let stream_id = queued_job.stream_id.clone();

    let (run_id, organization_id, environment_id) = match queued_job.job {
        Job::Workflow {
            ref run_id,
            ref organization_id,
            ref environment_id,
            ..
        } => (
            run_id.clone(),
            organization_id.clone(),
            environment_id.clone(),
        ),
        other => {
            let reason = format!("Expected workflow-compatible job, got {}", other.job_type());
            let _ = deps.queue.fail(&stream_id, &reason).await;
            return Err(WorkflowWorkerError::InvalidJobVariant(reason));
        }
    };

    let job_ctx = WorkflowJobContext {
        run_id: run_id.clone(),
        organization_id,
        environment_id,
    };

    match execute_workflow_pipeline(&deps, consumer_name, &stream_id, &job_ctx).await {
        Ok(result) => {
            // Both completed runs and parked approval gates terminate cleanly with ack
            deps.queue
                .ack(&stream_id)
                .await
                .map_err(|e| WorkflowWorkerError::Queue(e.to_string()))?;
            Ok(result)
        }
        Err(err) => {
            let error_message = err.to_string();
            eprintln!("Workflow run {run_id} execution failed: {error_message}");

            // Fail job in queue with error diagnostics per total failure contract
            let _ = deps.queue.fail(&stream_id, &error_message).await;
            Err(err)
        }
    }
}

/// Internal pipeline walking the steps of a workflow run.
async fn execute_workflow_pipeline(
    deps: &WorkflowWorkerDeps<'_>,
    consumer_name: &str,
    stream_id: &str,
    job_ctx: &WorkflowJobContext,
) -> Result<WorkflowWorkerResult, WorkflowWorkerError> {
    let WorkflowWorkerDeps {
        db,
        queue,
        executor,
    } = deps;
    // `db` arrives as `&&Database` after destructuring; the ORM's DbExecutor is implemented
    // for `&Database`, so reborrow once here rather than at every call site.
    let db: &Database = db;
    let run_pub_id = &job_ctx.run_id;

    // 1. Resolve workflow run record by public UUID
    let mut run = WorkflowRun::objects()
        .filter(q!(public_id = run_pub_id.to_owned()))?
        .first(db)
        .await?
        .ok_or_else(|| WorkflowWorkerError::RunNotFound(run_pub_id.clone()))?;

    // If run already reached terminal status, acknowledge and exit immediately
    if matches!(run.status.as_str(), "success" | "failed" | "cancelled") {
        return Ok(WorkflowWorkerResult {
            run_id: run.public_id,
            status: run.status,
            steps_completed: 0,
            parked_at_gate: false,
        });
    }

    // 2. Resolve parent workflow definition and app metadata
    let workflow = repositories::workflow_by_id(db, run.workflow_id.id)
        .await?
        .ok_or_else(|| WorkflowWorkerError::WorkflowNotFound(run.workflow_id.id.to_string()))?;

    let app = repositories::app_summary_by_id(db, workflow.app_id.id)
        .await?
        .ok_or_else(|| WorkflowWorkerError::WorkflowService("Parent app not found".to_string()))?;

    // Bound but unused: this resolves nothing the run needs, it asserts the owning
    // organization still exists before any child build or deployment is created for it.
    let _org = repositories::organization_summary_by_id(db, workflow.organization_id)
        .await?
        .ok_or_else(|| {
            WorkflowWorkerError::WorkflowService("Owning organization not found".to_string())
        })?;

    // 3. Concurrency guard: check active runs for this workflow and environment
    let existing_runs =
        repositories::workflow_runs_for_workflow(db, workflow.id, workflow.organization_id).await?;
    let summaries: Vec<WorkflowRunSummary> = existing_runs
        .into_iter()
        .map(|r| WorkflowRunSummary {
            id: r.id,
            workflow_id: r.workflow_id.id,
            status: r.status,
            environment: job_ctx.environment_id.clone(),
        })
        .collect();

    if !can_execute_run(
        &summaries,
        workflow.id,
        run.id,
        job_ctx.environment_id.as_deref(),
    ) {
        return Err(WorkflowWorkerError::ConcurrencyLimit {
            run_id: run.public_id.clone(),
            reason: format!(
                "An active run for workflow '{}' in environment '{:?}' is already in progress",
                workflow.public_id, job_ctx.environment_id
            ),
        });
    }

    // 4. Update run status to running if pending
    let now = Utc::now();
    if run.status == "pending" && can_run_transition(&run.status, "running") {
        {
            run.status = "running".to_string();
            run.started_at = Some(now);
            run.updated_at = now;
            repositories::update_workflow_run(db, &run).await?;

            emit_event(
                db,
                "workflowrun.started",
                Some(workflow.organization_id),
                Some(app.project_id),
                Some(app.id),
                None,
                serde_json::json!({
                    "run_id": run.public_id,
                    "workflow_id": workflow.public_id,
                }),
            )
            .await;
        }
    }

    // 5. Load ordered steps and initialize run context
    let mut steps = repositories::steps_for_workflow_run(db, run.id).await?;
    let mut run_ctx = WorkflowRunContext {
        run_id: run.public_id.clone(),
        workflow_id: workflow.public_id.clone(),
        run_db_id: run.id,
        organization_id: workflow.organization_id,
        git_commit: run.git_commit.clone(),
        git_branch: run.git_branch.clone(),
        git_ref: run.git_ref.clone(),
        environment: job_ctx.environment_id.clone(),
        step_outputs: HashMap::new(),
        last_build_artifact_id: None,
    };

    let mut steps_completed = 0;

    // 6. Walk steps sequentially in order
    for step_idx in 0..steps.len() {
        let step = &mut steps[step_idx];

        // Skip steps that are already completed
        if step.status == "completed" {
            steps_completed += 1;
            continue;
        }

        // Skip steps that are already skipped
        if step.status == "skipped" {
            continue;
        }

        // Heartbeat active claim to prevent visibility timeout during long-running work
        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| WorkflowWorkerError::Queue(e.to_string()))?;

        // 7. APPROVAL GATE: park the run without busy-waiting
        if (step.step_kind == "approval_gate" || step.requires_approval)
            && step.status != "completed"
        {
            {
                step.status = "blocked".to_string();
                repositories::update_workflow_run_step(db, step).await?;

                run.status = "blocked".to_string();
                run.updated_at = Utc::now();
                repositories::update_workflow_run(db, &run).await?;

                emit_event(
                    db,
                    "workflowrun.step.started",
                    Some(workflow.organization_id),
                    Some(app.project_id),
                    Some(app.id),
                    None,
                    serde_json::json!({
                        "run_id": run.public_id,
                        "step_id": step.public_id,
                        "step_name": step.name,
                        "requires_approval": true,
                    }),
                )
                .await;

                // Stop consuming worker slot immediately: clean park at gate
                return Ok(WorkflowWorkerResult {
                    run_id: run.public_id,
                    status: "blocked".to_string(),
                    steps_completed,
                    parked_at_gate: true,
                });
            }
        }

        // 8. Start step execution: transition to running
        let step_start_time = Utc::now();
        if can_step_transition(&step.status, "running") {
            step.status = "running".to_string();
            step.started_at = Some(step_start_time);
            repositories::update_workflow_run_step(db, step).await?;

            emit_event(
                db,
                "workflowrun.step.started",
                Some(workflow.organization_id),
                Some(app.project_id),
                Some(app.id),
                None,
                serde_json::json!({
                    "run_id": run.public_id,
                    "step_id": step.public_id,
                    "step_name": step.name,
                }),
            )
            .await;
        }

        // 9. Execute step kind
        let mut step_ctx = StepRunContext {
            step,
            app_summary: &app,
            organization_id: workflow.organization_id,
            actor_user_id: run.created_by_id,
        };

        let step_result = drive_step_kind(db, queue, *executor, &mut step_ctx, &run_ctx).await;

        match step_result {
            // A step that only queued child work is NOT finished. Park the run and release
            // the worker slot; the child's terminal status re-enqueues the run, which then
            // resumes at this same step. Marking it completed here would report success for
            // a build that has not run yet.
            Ok(ref output) if output.status == STEP_AWAITING_CHILD => {
                let park_time = Utc::now();
                step_ctx.step.status = "running".to_string();
                if let Some(ref stdout) = output.stdout {
                    step_ctx.step.log_snippet = Some(stdout.clone());
                }
                repositories::update_workflow_run_step(db, step_ctx.step).await?;

                run.status = "running".to_string();
                run.updated_at = park_time;
                repositories::update_workflow_run(db, &run).await?;

                emit_event(
                    db,
                    "workflowrun.step.started",
                    Some(workflow.organization_id),
                    Some(app.project_id),
                    Some(app.id),
                    None,
                    serde_json::json!({
                        "run_id": run.public_id,
                        "step_id": step_ctx.step.public_id,
                        "status": "running",
                        "awaiting": output.metadata.get("child_kind"),
                    }),
                )
                .await;

                queue
                    .ack(stream_id)
                    .await
                    .map_err(|e| WorkflowWorkerError::Queue(e.to_string()))?;

                return Ok(WorkflowWorkerResult {
                    run_id: run.public_id.clone(),
                    status: "running".to_string(),
                    steps_completed,
                    parked_at_gate: false,
                });
            }
            Ok(output) => {
                let finish_time = Utc::now();
                step_ctx.step.status = "completed".to_string();
                step_ctx.step.finished_at = Some(finish_time);
                if let Some(ref stdout) = output.stdout {
                    step_ctx.step.log_snippet = Some(stdout.clone());
                }
                repositories::update_workflow_run_step(db, step_ctx.step).await?;

                emit_event(
                    db,
                    "workflowrun.step.completed",
                    Some(workflow.organization_id),
                    Some(app.project_id),
                    Some(app.id),
                    None,
                    serde_json::json!({
                        "run_id": run.public_id,
                        "step_id": step_ctx.step.public_id,
                        "status": "completed",
                    }),
                )
                .await;

                run_ctx
                    .step_outputs
                    .insert(step_ctx.step.name.clone(), output);
                steps_completed += 1;
            }
            Err(step_err) => {
                let finish_time = Utc::now();
                let failure_reason = step_err.to_string();
                let continues = step_continues_on_error(&step_ctx.step.metadata);

                step_ctx.step.status = "failed".to_string();
                step_ctx.step.finished_at = Some(finish_time);
                step_ctx.step.log_snippet = Some(failure_reason.clone());
                repositories::update_workflow_run_step(db, step_ctx.step).await?;

                emit_event(
                    db,
                    "workflowrun.step.completed",
                    Some(workflow.organization_id),
                    Some(app.project_id),
                    Some(app.id),
                    None,
                    serde_json::json!({
                        "run_id": run.public_id,
                        "step_id": step_ctx.step.public_id,
                        "status": "failed",
                        "reason": failure_reason,
                        "continue_on_error": continues,
                    }),
                )
                .await;

                let output = StepOutput {
                    status: "failed".to_string(),
                    exit_code: None,
                    stdout: None,
                    stderr: Some(failure_reason.clone()),
                    metadata: serde_json::json!({ "error": failure_reason }),
                };
                run_ctx
                    .step_outputs
                    .insert(step_ctx.step.name.clone(), output);

                // Copy what the failure paths need out of the step now. Skipping the remaining
                // steps below borrows `steps` mutably again, which would collide with the
                // borrow `step_ctx` holds on this one.
                let failed_step_name = step_ctx.step.name.clone();
                let failed_step_kind = step_ctx.step.step_kind.clone();

                if continues {
                    // Step failed but workflow definition declared continue_on_error: proceed to next step
                    eprintln!(
                        "Step '{failed_step_name}' failed but continue_on_error is enabled: {failure_reason}"
                    );
                } else {
                    // Step failed and continue_on_error is false (default): fail the entire workflow run
                    for remaining_step in steps.iter_mut().skip(step_idx + 1) {
                        if remaining_step.status == "pending" {
                            remaining_step.status = "skipped".to_string();
                            repositories::update_workflow_run_step(db, remaining_step).await?;
                        }
                    }

                    run.status = "failed".to_string();
                    run.finished_at = Some(finish_time);
                    run.updated_at = finish_time;
                    repositories::update_workflow_run(db, &run).await?;

                    emit_event(
                        db,
                        "workflowrun.completed",
                        Some(workflow.organization_id),
                        Some(app.project_id),
                        Some(app.id),
                        None,
                        serde_json::json!({
                            "run_id": run.public_id,
                            "status": "failed",
                            "failed_step": failed_step_name,
                            "reason": failure_reason,
                        }),
                    )
                    .await;

                    return Err(WorkflowWorkerError::StepFailed {
                        step_name: failed_step_name,
                        step_kind: failed_step_kind,
                        reason: failure_reason,
                    });
                }
            }
        }
    }

    // 10. All steps completed successfully
    let finish_time = Utc::now();
    run.status = "success".to_string();
    run.finished_at = Some(finish_time);
    run.updated_at = finish_time;
    repositories::update_workflow_run(db, &run).await?;

    emit_event(
        db,
        "workflowrun.completed",
        Some(workflow.organization_id),
        Some(app.project_id),
        Some(app.id),
        None,
        serde_json::json!({
            "run_id": run.public_id,
            "status": "success",
            "steps_completed": steps_completed,
        }),
    )
    .await;

    Ok(WorkflowWorkerResult {
        run_id: run.public_id,
        status: "success".to_string(),
        steps_completed,
        parked_at_gate: false,
    })
}

/// Drives an individual step based on its declared `VALID_STEP_KINDS` kind.
async fn drive_step_kind(
    db: &Database,
    queue: &JobQueue,
    executor: &dyn CommandExecutor,
    step_ctx: &mut StepRunContext<'_>,
    run_ctx: &WorkflowRunContext,
) -> Result<StepOutput, WorkflowWorkerError> {
    let step_kind = step_ctx.step.step_kind.as_str();

    match step_kind {
        "test" | "build" => {
            // Go through the builds service rather than pushing a Job::Build directly: it
            // creates the real Build row and its stages, applies the org's billing and
            // concurrency checks, and enqueues the job itself. Synthesising a build_id here
            // would enqueue a job whose build record does not exist.
            let environment_id =
                run_ctx
                    .environment
                    .clone()
                    .ok_or_else(|| WorkflowWorkerError::StepFailed {
                        step_name: step_ctx.step.name.clone(),
                        step_kind: step_kind.to_string(),
                        reason: "A build step requires the run to target an environment"
                            .to_string(),
                    })?;

            let (build, _stages, _app, _env, _org) = crate::apps::builds::services::create_build(
                db,
                step_ctx.organization_id,
                None,
                queue,
                crate::apps::builds::contracts::BuildCreateRequest {
                    app_id: step_ctx.app_summary.public_id.clone(),
                    environment_id,
                    platform: if step_kind == "test" {
                        "test".to_string()
                    } else {
                        "all".to_string()
                    },
                    git_commit: Some(run_ctx.git_commit.clone()),
                    git_branch: Some(run_ctx.git_branch.clone()),
                    git_ref: Some(run_ctx.git_ref.clone()),
                    // The environment supplies the profile and toolchain pins; a workflow
                    // step must not silently override what the environment declares.
                    build_profile: None,
                    flutter_version: None,
                    dart_version: None,
                    bloom_version: None,
                    flavor: None,
                },
                // This is the edge the parked run is woken through.
                Some(step_ctx.step.id),
            )
            .await
            .map_err(|e| WorkflowWorkerError::StepFailed {
                step_name: step_ctx.step.name.clone(),
                step_kind: step_kind.to_string(),
                reason: e.to_string(),
            })?;

            // The step is NOT complete -- the build has only been queued. The run parks here
            // and resumes when the build reaches a terminal state.
            Ok(StepOutput {
                status: STEP_AWAITING_CHILD.to_string(),
                exit_code: None,
                stdout: Some(format!("Queued {step_kind} as build {}", build.public_id)),
                stderr: None,
                metadata: serde_json::json!({
                    "child_kind": "build",
                    "build_id": build.public_id,
                }),
            })
        }
        "deploy_preview" | "deploy_production" => {
            let target = if step_kind == "deploy_preview" {
                "preview"
            } else {
                "production"
            };

            // A deploy needs a real artifact, and the only artifact a run can legitimately
            // deploy is the one produced by an earlier build step in the same run. Look it
            // up from the recorded step outputs rather than synthesising an artifact id.
            let artifact_id = run_ctx.last_build_artifact_id.clone().ok_or_else(|| {
                WorkflowWorkerError::StepFailed {
                    step_name: step_ctx.step.name.clone(),
                    step_kind: step_kind.to_string(),
                    reason: "No artifact from an earlier build step in this run to deploy"
                        .to_string(),
                }
            })?;

            let environment_id =
                run_ctx
                    .environment
                    .clone()
                    .ok_or_else(|| WorkflowWorkerError::StepFailed {
                        step_name: step_ctx.step.name.clone(),
                        step_kind: step_kind.to_string(),
                        reason: "A deploy step requires the run to target an environment"
                            .to_string(),
                    })?;

            let detail = crate::apps::deployments::services::create_deployment(
                db,
                Some(queue),
                step_ctx.organization_id,
                step_ctx.actor_user_id,
                OrganizationRole::Admin,
                crate::apps::deployments::contracts::DeploymentCreateRequest {
                    release_id: None,
                    artifact_id: Some(artifact_id),
                    environment_id,
                    platform: "web".to_string(),
                    target: target.to_string(),
                },
                // This is the edge the parked run is woken through.
                Some(step_ctx.step.id),
            )
            .await
            .map_err(|e| WorkflowWorkerError::StepFailed {
                step_name: step_ctx.step.name.clone(),
                step_kind: step_kind.to_string(),
                reason: e.to_string(),
            })?;

            Ok(StepOutput {
                status: STEP_AWAITING_CHILD.to_string(),
                exit_code: None,
                stdout: Some(format!(
                    "Queued {step_kind} to '{target}' as deployment {}",
                    detail.deployment.public_id
                )),
                stderr: None,
                metadata: serde_json::json!({
                    "child_kind": "deploy",
                    "deployment_id": detail.deployment.public_id,
                    "target": target,
                }),
            })
        }
        "custom" => {
            // Declared command via Phase 9 CommandExecutor
            let meta: serde_json::Value = serde_json::from_str(&step_ctx.step.metadata)
                .unwrap_or_else(|_| serde_json::json!({}));

            let program = meta
                .get("program")
                .and_then(|v| v.as_str())
                .or_else(|| meta.get("command").and_then(|v| v.as_str()))
                .unwrap_or("echo")
                .to_string();

            let args: Vec<String> = meta
                .get("args")
                .and_then(|v| v.as_array())
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str().map(ToString::to_string))
                        .collect()
                })
                .unwrap_or_else(|| {
                    if let Some(script) = meta.get("script").and_then(|v| v.as_str()) {
                        vec![script.to_string()]
                    } else {
                        vec![format!("Executing step {}", step_ctx.step.name)]
                    }
                });

            let working_dir = meta
                .get("working_dir")
                .and_then(|v| v.as_str())
                .map(PathBuf::from)
                .unwrap_or_else(|| PathBuf::from("."));

            let timeout_secs = meta
                .get("timeout_secs")
                .and_then(|v| v.as_u64())
                .unwrap_or(DEFAULT_STEP_TIMEOUT_SECS);

            let mut spec = CommandSpec::new(program, working_dir)
                .with_args(args)
                .with_timeout(Duration::from_secs(timeout_secs))
                .with_env_var("BLOOM_RUN_ID", &run_ctx.run_id)
                .with_env_var("BLOOM_GIT_COMMIT", &run_ctx.git_commit)
                .with_env_var("BLOOM_GIT_BRANCH", &run_ctx.git_branch)
                .with_env_var("BLOOM_STEP_NAME", &step_ctx.step.name);

            // Pass outputs from prior steps to downstream environment
            for (prev_step_name, prev_output) in &run_ctx.step_outputs {
                let sanitized_name = prev_step_name
                    .to_uppercase()
                    .replace(|c: char| !c.is_ascii_alphanumeric(), "_");

                spec = spec.with_env_var(
                    format!("BLOOM_STEP_{sanitized_name}_STATUS"),
                    &prev_output.status,
                );

                if let Some(ref stdout) = prev_output.stdout {
                    spec = spec.with_env_var(format!("BLOOM_STEP_{sanitized_name}_STDOUT"), stdout);
                }
            }

            let output = executor.run(&spec).await.map_err(|e| match e {
                ExecutorError::NonZeroExit { code, stderr } => WorkflowWorkerError::StepFailed {
                    step_name: step_ctx.step.name.clone(),
                    step_kind: "custom".to_string(),
                    reason: format!("Command exited with code {:?}: {stderr}", code),
                },
                ExecutorError::Timeout { seconds } => WorkflowWorkerError::StepFailed {
                    step_name: step_ctx.step.name.clone(),
                    step_kind: "custom".to_string(),
                    reason: format!("Command timed out after {seconds} seconds"),
                },
                other => WorkflowWorkerError::Executor(other.to_string()),
            })?;

            Ok(StepOutput {
                status: "completed".to_string(),
                exit_code: output.exit_code,
                stdout: Some(output.stdout),
                stderr: Some(output.stderr),
                metadata: serde_json::json!({
                    "duration_ms": output.duration.as_millis(),
                }),
            })
        }
        "approval_gate" => {
            // Handled before drive_step_kind
            Ok(StepOutput {
                status: "blocked".to_string(),
                exit_code: None,
                stdout: Some("Approval gate pending".to_string()),
                stderr: None,
                metadata: serde_json::json!({ "requires_approval": true }),
            })
        }
        unknown => Err(WorkflowWorkerError::StepFailed {
            step_name: step_ctx.step.name.clone(),
            step_kind: unknown.to_string(),
            reason: format!(
                "Unrecognized step kind '{unknown}' (valid: {:?})",
                VALID_STEP_KINDS
            ),
        }),
    }
}
