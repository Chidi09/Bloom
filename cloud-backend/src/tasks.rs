//! Recurring background tasks.
//!
//! `docs/infrastructure.md` section 2 splits background work in two: the custom Redis Streams
//! queue drives build and deploy jobs, which need platform containers and job-scoped tokens,
//! while everything else — cleanup, polling, retention — runs on `djangors-tasks`. The crate
//! was declared as a dependency and then never used, so the retention work below had no
//! runner at all and the affected tables grew without bound.
//!
//! Handlers take only a serializable payload and read the database through
//! [`crate::runtime::db`]. They are registered at link time by the `#[task]` macro, which is
//! why [`register_recurring_tasks`] only has to name them.

use djangors_tasks::{task, TaskError};

use crate::runtime;

/// Cron schedule for the install-dedup purge: hourly, on the hour.
///
/// Rows are only useful for the 24-hour bucket they were written in, so hourly is frequent
/// enough that the table stays small and infrequent enough to stay off the critical path.
pub const PURGE_INSTALL_DEDUP_CRON: &str = "0 * * * *";

/// Cron schedule for the device-flow sweep: every fifteen minutes.
///
/// Device codes expire in minutes, so a sweep this often keeps expired rows from accumulating
/// between logins without polling pointlessly.
pub const EXPIRE_DEVICE_FLOWS_CRON: &str = "*/15 * * * *";

/// Retention window for install deduplication rows.
///
/// The model documents that rows older than 48 hours can be purged without affecting
/// aggregate counts: the durable counters were already incremented at install time, and the
/// dedup window is daily. 48 hours rather than 24 leaves a full bucket of margin for clock
/// skew between instances.
pub const INSTALL_DEDUP_RETENTION_HOURS: i64 = 48;

/// Deletes install deduplication rows past the retention window.
///
/// Without this the table grows by one row per unique installer per template per day and is
/// never read again after its bucket closes.
#[task]
pub async fn purge_install_dedup() -> Result<(), TaskError> {
    let db = runtime::db();
    let cutoff = chrono::Utc::now() - chrono::Duration::hours(INSTALL_DEDUP_RETENTION_HOURS);

    let removed = crate::apps::marketplace::repositories::delete_install_dedup_before(db, cutoff)
        .await
        .map_err(|e| TaskError::TaskExecution(e.to_string()))?;

    // This crate has no logging framework; src/main.rs uses eprintln! for the same purpose.
    eprintln!("task purge_install_dedup removed {removed} row(s)");
    Ok(())
}

/// Marks device-flow authorization requests as expired once their deadline has passed.
///
/// The poll endpoint already expires a request lazily when it is asked about, but a request
/// nobody polls again stays `pending` forever, so the table keeps rows that look actionable
/// and never are.
#[task]
pub async fn expire_device_flows() -> Result<(), TaskError> {
    let db = runtime::db();

    let expired = crate::apps::accounts::repositories::expire_stale_device_flows(db)
        .await
        .map_err(|e| TaskError::TaskExecution(e.to_string()))?;

    eprintln!("task expire_device_flows marked {expired} request(s) expired");
    Ok(())
}

/// Registers every recurring task's schedule.
///
/// Registration is idempotent per row in intent but not enforced by the framework, so this is
/// safe to call at startup only because a duplicate schedule would merely enqueue the same
/// cleanup twice — both handlers are themselves idempotent. Failures are logged rather than
/// propagated: a control plane that cannot register a cleanup schedule should still serve
/// traffic.
pub async fn register_recurring_tasks(db: &djangors_db::Database) {
    let schedules = [
        ("purge_install_dedup", PURGE_INSTALL_DEDUP_CRON),
        ("expire_device_flows", EXPIRE_DEVICE_FLOWS_CRON),
    ];

    for (name, cron) in schedules {
        if let Err(error) = djangors_tasks::register_recurring(db, name, &(), cron).await {
            eprintln!("failed to register recurring task {name}: {error}");
        }
    }
}
