//! Process-global handles for background task handlers.
//!
//! A `#[task]` handler receives only a serializable payload and has no request context, so it
//! cannot be handed the `Database` the way a view is. The server installs the handle once at
//! startup, before the worker loop begins, and handlers read it back.
//!
//! This exists because of how `djangors-tasks` invokes handlers, not by preference. Nothing
//! outside a task handler should reach for these — views take state from the request.

use std::sync::OnceLock;

use djangors_db::Database;

static DB: OnceLock<Database> = OnceLock::new();

/// Installs the process-global database handle. Called once at startup.
///
/// Subsequent calls are ignored rather than panicking, so a test harness that boots more than
/// once in a process does not abort.
pub fn set_db(db: Database) {
    let _ = DB.set(db);
}

/// Returns the process-global database handle.
///
/// # Panics
///
/// Panics if the handle was never installed. That is a wiring mistake rather than a runtime
/// condition: the worker only starts after the server calls [`set_db`], so reaching this panic
/// means a task handler ran before startup finished.
pub fn db() -> &'static Database {
    DB.get()
        .expect("global database handle not installed; call runtime::set_db at startup")
}

/// Returns the process-global database handle if one was installed.
///
/// Prefer [`db`] inside task handlers. This is for code that may legitimately run before
/// startup completes and should degrade rather than abort.
pub fn try_db() -> Option<&'static Database> {
    DB.get()
}
