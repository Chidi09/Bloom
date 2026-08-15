//! Tests for the recurring-task schedules and retention constants.
//!
//! The handlers themselves need a live database (they are `#[task]` functions reading the
//! process-global handle), so what is asserted here is the part that is wrong silently: a
//! malformed cron expression registers nothing and the sweep simply never runs.

use bloom_cloud_backend::tasks::{
    EXPIRE_DEVICE_FLOWS_CRON, INSTALL_DEDUP_RETENTION_HOURS, PURGE_INSTALL_DEDUP_CRON,
};

/// Parses a cron expression exactly as `djangors_tasks::parse_schedule` does.
///
/// That function requires exactly five fields and prepends a seconds field before handing the
/// string to `cron`, which itself expects six. Mirroring it matters: parsing the raw
/// five-field expression directly rejects every valid schedule, and parsing a six-field one
/// would accept expressions `register_recurring` refuses.
fn parse_like_djangors(expr: &str) -> Option<cron::Schedule> {
    use std::str::FromStr;

    if expr.split_whitespace().count() != 5 {
        return None;
    }
    cron::Schedule::from_str(&format!("0 {expr}")).ok()
}

/// True when `expr` would be accepted at registration.
fn parses_as_cron(expr: &str) -> bool {
    parse_like_djangors(expr).is_some()
}

#[test]
fn test_recurring_schedules_are_valid_cron() {
    // register_recurring rejects a malformed expression and logs, so a typo here would leave
    // the retention sweep silently unregistered and the table growing forever.
    assert!(
        parses_as_cron(PURGE_INSTALL_DEDUP_CRON),
        "purge schedule must parse: {PURGE_INSTALL_DEDUP_CRON}"
    );
    assert!(
        parses_as_cron(EXPIRE_DEVICE_FLOWS_CRON),
        "device flow schedule must parse: {EXPIRE_DEVICE_FLOWS_CRON}"
    );
}

#[test]
fn test_schedules_have_a_future_occurrence() {
    // register_recurring also requires an upcoming occurrence to compute next_run_at; an
    // expression that parses but never fires would register and then never run.
    for expr in [PURGE_INSTALL_DEDUP_CRON, EXPIRE_DEVICE_FLOWS_CRON] {
        let schedule = parse_like_djangors(expr).expect("schedule parses");
        assert!(
            schedule.upcoming(chrono::Utc).next().is_some(),
            "{expr} must have a future occurrence"
        );
    }
}

#[test]
fn test_install_dedup_retention_outlives_the_dedup_window() {
    // The dedup bucket is one calendar day. Purging at or below 24h could drop a row whose
    // bucket is still open, letting the same actor be counted twice.
    assert_eq!(INSTALL_DEDUP_RETENTION_HOURS, 48);
}
