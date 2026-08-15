use std::collections::HashSet;

use bloom_cloud_backend::apps::releases::services::{
    can_transition, validate_commit, validate_platforms, validate_status, validate_version,
    VALID_PLATFORMS, VALID_STATUSES,
};

#[test]
fn test_release_status_transition_matrix() {
    // The exhaustive set of legal release transitions.
    // Documents the conservative matrix:
    // - terminal states (`rolled_back`, `expired`) are strictly absorbing
    // - `draft` can advance to `pending_approval`, `approved`, or `expired`
    // - `pending_approval` can advance to `approved`, return to `draft` (rejection), or `expired`
    // - `approved` can advance to `rolling_out`, `released`, or `expired`
    // - `rolling_out` can advance to `released`, `rolled_back`, or `expired`
    // - `released` can transition to `rolled_back` or `expired`
    let legal: HashSet<(&str, &str)> = [
        ("draft", "pending_approval"),
        ("draft", "approved"),
        ("draft", "expired"),
        ("pending_approval", "approved"),
        ("pending_approval", "draft"),
        ("pending_approval", "expired"),
        ("approved", "rolling_out"),
        ("approved", "released"),
        ("approved", "expired"),
        ("rolling_out", "released"),
        ("rolling_out", "rolled_back"),
        ("rolling_out", "expired"),
        ("released", "rolled_back"),
        ("released", "expired"),
    ]
    .into_iter()
    .collect();

    let statuses = [
        "draft",
        "pending_approval",
        "approved",
        "rolling_out",
        "released",
        "rolled_back",
        "expired",
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
fn test_release_terminal_states_are_absorbing() {
    let all_statuses = [
        "draft",
        "pending_approval",
        "approved",
        "rolling_out",
        "released",
        "rolled_back",
        "expired",
    ];

    // Terminal states never transition anywhere
    for to in all_statuses {
        assert!(
            !can_transition("rolled_back", to),
            "rolled_back -> {to} must be illegal"
        );
        assert!(
            !can_transition("expired", to),
            "expired -> {to} must be illegal"
        );
    }
}

#[test]
fn test_rejection_and_approval_transitions() {
    // pending_approval -> approved (approval) is legal
    assert!(can_transition("pending_approval", "approved"));

    // pending_approval -> draft (rejection) is legal
    assert!(can_transition("pending_approval", "draft"));

    // released cannot return to draft or pending_approval
    assert!(!can_transition("released", "draft"));
    assert!(!can_transition("released", "pending_approval"));
    assert!(!can_transition("released", "approved"));

    // approved cannot return to draft or pending_approval
    assert!(!can_transition("approved", "draft"));
    assert!(!can_transition("approved", "pending_approval"));
}

#[test]
fn test_version_validation() {
    // Valid semver strings
    assert!(validate_version("1.0.0").is_ok());
    assert!(validate_version("0.1.0").is_ok());
    assert!(validate_version("2.1.3-beta.1").is_ok());
    assert!(validate_version("v1.2.3").is_ok());
    assert!(validate_version("1.0.0+20130313144700").is_ok());

    // Invalid versions
    assert!(validate_version("").is_err());
    assert!(validate_version("   ").is_err());
    assert!(validate_version("invalid_version").is_err());
    assert!(validate_version(&"a".repeat(65)).is_err());
}

#[test]
fn test_platforms_validation() {
    // Valid platform sets
    assert!(validate_platforms(&["ios".to_string()]).is_ok());
    assert!(validate_platforms(&["android".to_string()]).is_ok());
    assert!(validate_platforms(&["web".to_string()]).is_ok());
    assert!(
        validate_platforms(&["ios".to_string(), "android".to_string(), "web".to_string()]).is_ok()
    );

    // Invalid platforms
    assert!(validate_platforms(&[]).is_err());
    assert!(validate_platforms(&["windows".to_string()]).is_err());
    assert!(validate_platforms(&["macos".to_string()]).is_err());
    assert!(validate_platforms(&["ios".to_string(), "invalid".to_string()]).is_err());

    assert_eq!(VALID_PLATFORMS, &["ios", "android", "web"]);
}

#[test]
fn test_commit_validation() {
    assert!(validate_commit("abc1234").is_ok());
    assert!(validate_commit("0123456789abcdef0123456789abcdef01234567").is_ok());

    assert!(validate_commit("").is_err());
    assert!(validate_commit("not_hex_zzzz").is_err());
    assert!(validate_commit(&"a".repeat(41)).is_err());
}

#[test]
fn test_status_validation() {
    for status in VALID_STATUSES {
        assert!(validate_status(status).is_ok(), "{status} must be valid");
    }

    assert!(validate_status("unknown_status").is_err());
    assert!(validate_status("").is_err());

    assert_eq!(
        VALID_STATUSES,
        &[
            "draft",
            "pending_approval",
            "approved",
            "rolling_out",
            "released",
            "rolled_back",
            "expired",
        ]
    );
}
