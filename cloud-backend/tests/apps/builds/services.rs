use std::collections::HashSet;

use bloom_cloud_backend::apps::builds::services::{
    can_stage_transition, can_transition, validate_build_profile, validate_platform,
    validate_stage_name, validate_stage_status, BUILD_STAGES, VALID_BUILD_PROFILES,
    VALID_PLATFORMS, VALID_STAGE_STATUSES,
};

#[test]
fn test_build_status_transition_matrix() {
    // The exhaustive set of legal transitions. This documents the conservative
    // matrix: terminal states are absorbing, `pending` is only a source (never a
    // target), and `running` is reachable only from `queued`.
    let legal: HashSet<(&str, &str)> = [
        ("pending", "queued"),
        ("pending", "cancelled"),
        ("queued", "running"),
        ("queued", "cancelled"),
        ("queued", "failed"),
        ("running", "success"),
        ("running", "failed"),
        ("running", "cancelled"),
    ]
    .into_iter()
    .collect();

    let statuses = [
        "pending",
        "queued",
        "running",
        "success",
        "failed",
        "cancelled",
    ];

    for from in statuses {
        for to in statuses {
            let expected = legal.contains(&(from, to));
            let actual = can_transition(from, to);
            assert_eq!(
                actual, expected,
                "can_transition({from}, {to}) should be {expected}"
            );
        }
    }
}

#[test]
fn test_build_status_transition_key_edges() {
    // Terminal states never transition anywhere.
    for to in [
        "pending",
        "queued",
        "running",
        "success",
        "failed",
        "cancelled",
    ] {
        assert!(
            !can_transition("success", to),
            "success -> {to} must be illegal"
        );
        assert!(
            !can_transition("failed", to),
            "failed -> {to} must be illegal"
        );
        assert!(
            !can_transition("cancelled", to),
            "cancelled -> {to} must be illegal"
        );
    }

    // Nothing ever returns to pending.
    for from in ["queued", "running", "success", "failed", "cancelled"] {
        assert!(
            !can_transition(from, "pending"),
            "{from} -> pending must be illegal"
        );
    }

    // Running is reachable only from queued.
    assert!(can_transition("queued", "running"));
    assert!(!can_transition("pending", "running"));
    assert!(!can_transition("running", "running"));
    assert!(!can_transition("success", "running"));

    // Cancellation is allowed from pending/queued/running, not from terminal states.
    assert!(can_transition("pending", "cancelled"));
    assert!(can_transition("queued", "cancelled"));
    assert!(can_transition("running", "cancelled"));
}

#[test]
fn test_stage_status_transition_matrix() {
    let legal: HashSet<(&str, &str)> = [
        ("pending", "running"),
        ("pending", "completed"),
        ("pending", "failed"),
        ("pending", "skipped"),
        ("running", "completed"),
        ("running", "failed"),
        ("running", "skipped"),
    ]
    .into_iter()
    .collect();

    let statuses = ["pending", "running", "completed", "failed", "skipped"];

    for from in statuses {
        for to in statuses {
            let expected = legal.contains(&(from, to));
            let actual = can_stage_transition(from, to);
            assert_eq!(
                actual, expected,
                "can_stage_transition({from}, {to}) should be {expected}"
            );
        }
    }
}

#[test]
fn test_platform_validation() {
    assert!(validate_platform("android").is_ok());
    assert!(validate_platform("ios").is_ok());
    assert!(validate_platform("web").is_ok());
    assert!(validate_platform("all").is_ok());

    assert!(validate_platform("linux").is_err());
    assert!(validate_platform("windows").is_err());
    assert!(validate_platform("").is_err());

    assert_eq!(VALID_PLATFORMS, &["android", "ios", "web", "all"]);
}

#[test]
fn test_build_profile_validation() {
    assert!(validate_build_profile("debug").is_ok());
    assert!(validate_build_profile("profile").is_ok());
    assert!(validate_build_profile("release").is_ok());

    assert!(validate_build_profile("prod").is_err());
    assert!(validate_build_profile("").is_err());

    assert_eq!(VALID_BUILD_PROFILES, &["debug", "profile", "release"]);
}

#[test]
fn test_stage_name_validation() {
    for stage in BUILD_STAGES {
        assert!(validate_stage_name(stage).is_ok(), "{stage} must be valid");
    }

    assert!(validate_stage_name("not_a_stage").is_err());
    assert!(validate_stage_name("").is_err());

    assert_eq!(
        BUILD_STAGES,
        &[
            "checkout", "install", "resolve", "generate", "prebuild", "test", "analyze", "build",
            "upload",
        ]
    );
}

#[test]
fn test_stage_status_validation() {
    for status in VALID_STAGE_STATUSES {
        assert!(
            validate_stage_status(status).is_ok(),
            "{status} must be valid"
        );
    }

    assert!(validate_stage_status("blocked").is_err());
    assert!(validate_stage_status("").is_err());

    assert_eq!(
        VALID_STAGE_STATUSES,
        &["pending", "running", "completed", "failed", "skipped"]
    );
}

#[test]
fn test_build_cancel_key_format() {
    use bloom_cloud_backend::apps::builds::services::build_cancel_key;

    let build_id = "550e8400-e29b-41d4-a716-446655440000";
    let key = build_cancel_key(build_id);
    assert_eq!(
        key,
        "bloomcloud:builds:550e8400-e29b-41d4-a716-446655440000:cancel"
    );
}

#[test]
fn test_cancelling_terminal_states_transitions_matrix() {
    // The transition matrix does not allow transitions out of terminal states,
    // but the high-level service function treats cancelling an already-terminal
    // build (success, failed, cancelled) as an idempotent no-op.
    assert!(!can_transition("success", "cancelled"));
    assert!(!can_transition("failed", "cancelled"));
    assert!(!can_transition("cancelled", "cancelled"));
}
