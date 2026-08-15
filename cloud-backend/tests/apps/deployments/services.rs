use bloom_cloud_backend::apps::deployments::services::{
    can_transition, is_production_target, validate_platform_and_target, VALID_PLATFORMS,
    VALID_STATUSES, VALID_TARGETS,
};

#[test]
fn test_transition_matrix_exhaustive() {
    let statuses = [
        "pending",
        "queued",
        "running",
        "processing",
        "ready",
        "live",
        "failed",
        "rolled_back",
    ];

    // Legal transitions per specification and service docs:
    // pending -> queued, running, failed
    // queued -> running, failed
    // running -> processing, ready, live, failed
    // processing -> ready, live, failed
    // ready -> rolled_back (absorbing terminal state otherwise)
    // live -> rolled_back (absorbing terminal state otherwise)
    // failed -> none (strictly absorbing)
    // rolled_back -> none (strictly absorbing)
    for from in &statuses {
        for to in &statuses {
            let allowed = can_transition(from, to);
            match (*from, *to) {
                ("pending", "queued") => assert!(allowed, "pending -> queued must be allowed"),
                ("pending", "running") => assert!(allowed, "pending -> running must be allowed"),
                ("pending", "failed") => assert!(allowed, "pending -> failed must be allowed"),
                ("queued", "running") => assert!(allowed, "queued -> running must be allowed"),
                ("queued", "failed") => assert!(allowed, "queued -> failed must be allowed"),
                ("running", "processing") => {
                    assert!(allowed, "running -> processing must be allowed")
                }
                ("running", "ready") => assert!(allowed, "running -> ready must be allowed"),
                ("running", "live") => assert!(allowed, "running -> live must be allowed"),
                ("running", "failed") => assert!(allowed, "running -> failed must be allowed"),
                ("processing", "ready") => {
                    assert!(allowed, "processing -> ready must be allowed")
                }
                ("processing", "live") => assert!(allowed, "processing -> live must be allowed"),
                ("processing", "failed") => {
                    assert!(allowed, "processing -> failed must be allowed")
                }
                ("ready", "rolled_back") => {
                    assert!(allowed, "ready -> rolled_back must be allowed")
                }
                ("live", "rolled_back") => {
                    assert!(allowed, "live -> rolled_back must be allowed")
                }
                _ => assert!(
                    !allowed,
                    "Transition from '{from}' to '{to}' must NOT be allowed"
                ),
            }
        }
    }
}

#[test]
fn test_terminal_absorbing_states() {
    let targets = [
        "pending",
        "queued",
        "running",
        "processing",
        "ready",
        "live",
        "failed",
        "rolled_back",
    ];

    // Failed cannot transition anywhere
    for to in &targets {
        assert!(
            !can_transition("failed", to),
            "failed cannot transition to {to}"
        );
    }

    // Rolled back cannot transition anywhere
    for to in &targets {
        assert!(
            !can_transition("rolled_back", to),
            "rolled_back cannot transition to {to}"
        );
    }

    // Ready and live can ONLY transition to rolled_back
    for to in &targets {
        if *to != "rolled_back" {
            assert!(
                !can_transition("ready", to),
                "ready cannot transition to {to}"
            );
            assert!(
                !can_transition("live", to),
                "live cannot transition to {to}"
            );
        }
    }
}

#[test]
fn test_platform_and_target_validation() {
    // Valid iOS targets
    assert!(validate_platform_and_target("ios", "testflight").is_ok());
    assert!(validate_platform_and_target("ios", "app_store").is_ok());
    assert!(validate_platform_and_target("ios", "internal").is_err());
    assert!(validate_platform_and_target("ios", "preview").is_err());

    // Valid Android targets
    assert!(validate_platform_and_target("android", "internal").is_ok());
    assert!(validate_platform_and_target("android", "closed").is_ok());
    assert!(validate_platform_and_target("android", "open").is_ok());
    assert!(validate_platform_and_target("android", "production").is_ok());
    assert!(validate_platform_and_target("android", "testflight").is_err());
    assert!(validate_platform_and_target("android", "preview").is_err());

    // Valid Web targets
    assert!(validate_platform_and_target("web", "preview").is_ok());
    assert!(validate_platform_and_target("web", "production").is_ok());
    assert!(validate_platform_and_target("web", "testflight").is_err());
    assert!(validate_platform_and_target("web", "internal").is_err());

    // Invalid platform / target
    assert!(validate_platform_and_target("windows", "production").is_err());
    assert!(validate_platform_and_target("ios", "custom").is_err());
}

#[test]
fn test_is_production_target() {
    assert!(is_production_target("production"));
    assert!(is_production_target("app_store"));
    assert!(!is_production_target("testflight"));
    assert!(!is_production_target("internal"));
    assert!(!is_production_target("closed"));
    assert!(!is_production_target("open"));
    assert!(!is_production_target("preview"));
}

#[test]
fn test_constants_completeness() {
    assert_eq!(VALID_PLATFORMS, &["ios", "android", "web"]);
    assert_eq!(
        VALID_TARGETS,
        &[
            "testflight",
            "app_store",
            "internal",
            "closed",
            "open",
            "production",
            "preview"
        ]
    );
    assert_eq!(
        VALID_STATUSES,
        &[
            "pending",
            "queued",
            "running",
            "processing",
            "ready",
            "live",
            "failed",
            "rolled_back"
        ]
    );
}
