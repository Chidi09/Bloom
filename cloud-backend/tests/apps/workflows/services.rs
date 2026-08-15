use std::collections::HashSet;

use bloom_cloud_backend::apps::workflows::services::{
    can_run_transition, can_step_transition, parse_workflow_definition,
    validate_workflow_name_and_slug, VALID_RUN_STATUSES, VALID_STEP_STATUSES,
};

#[test]
fn test_workflow_run_status_transition_matrix_exhaustive() {
    let legal: HashSet<(&str, &str)> = [
        ("pending", "running"),
        ("pending", "blocked"),
        ("pending", "cancelled"),
        ("running", "blocked"),
        ("running", "success"),
        ("running", "failed"),
        ("running", "cancelled"),
        ("blocked", "running"),
        ("blocked", "failed"),
        ("blocked", "cancelled"),
    ]
    .into_iter()
    .collect();

    for from in VALID_RUN_STATUSES {
        for to in VALID_RUN_STATUSES {
            let expected = legal.contains(&(from, to));
            let actual = can_run_transition(from, to);
            assert_eq!(
                actual, expected,
                "can_run_transition({from}, {to}) should be {expected}"
            );
        }
    }
}

#[test]
fn test_workflow_run_status_terminal_states_absorb() {
    for terminal in ["success", "failed", "cancelled"] {
        for to in VALID_RUN_STATUSES {
            assert!(
                !can_run_transition(terminal, to),
                "terminal state {terminal} must not transition to {to}"
            );
        }
    }
}

#[test]
fn test_workflow_step_status_transition_matrix_exhaustive() {
    let legal: HashSet<(&str, &str)> = [
        ("pending", "running"),
        ("pending", "blocked"),
        ("pending", "skipped"),
        ("running", "completed"),
        ("running", "failed"),
        ("running", "skipped"),
        ("blocked", "completed"),
        ("blocked", "failed"),
        ("blocked", "skipped"),
    ]
    .into_iter()
    .collect();

    for from in VALID_STEP_STATUSES {
        for to in VALID_STEP_STATUSES {
            let expected = legal.contains(&(from, to));
            let actual = can_step_transition(from, to);
            assert_eq!(
                actual, expected,
                "can_step_transition({from}, {to}) should be {expected}"
            );
        }
    }
}

#[test]
fn test_workflow_step_status_terminal_states_absorb() {
    for terminal in ["completed", "failed", "skipped"] {
        for to in VALID_STEP_STATUSES {
            assert!(
                !can_step_transition(terminal, to),
                "step terminal state {terminal} must not transition to {to}"
            );
        }
    }
}

#[test]
fn test_workflow_validation() {
    assert!(validate_workflow_name_and_slug("CI Pipeline", "ci-pipeline").is_ok());
    assert!(validate_workflow_name_and_slug("Deploy Web", "deploy_web").is_ok());

    // Empty name or slug
    assert!(validate_workflow_name_and_slug("", "ci").is_err());
    assert!(validate_workflow_name_and_slug("CI", "").is_err());

    // Invalid slug characters
    assert!(validate_workflow_name_and_slug("CI", "ci/pipeline").is_err());
    assert!(validate_workflow_name_and_slug("CI", "ci pipeline").is_err());
}

#[test]
fn test_workflow_definition_parses_the_authored_steps() {
    // The steps returned must be the ones the author actually wrote — not a canonical
    // pipeline. An earlier implementation ignored the document and always returned the same
    // five steps, which would have silently run steps nobody declared.
    let yaml = r#"
steps:
  - name: run tests
    kind: test
  - name: build app
    kind: build
  - name: ship it
    kind: deploy_production
"#;
    let steps = parse_workflow_definition(yaml).expect("valid definition parses");

    assert_eq!(steps.len(), 3, "must return exactly the authored steps");
    assert_eq!(steps[0].name, "run tests");
    assert_eq!(steps[0].step_kind, "test");
    assert_eq!(steps[1].name, "build app");
    assert_eq!(steps[2].step_kind, "deploy_production");

    // Document order becomes 1-based step_order.
    for (i, step) in steps.iter().enumerate() {
        assert_eq!(step.step_order, (i + 1) as i64);
    }

    // Nothing in this document asks for approval.
    assert!(steps.iter().all(|s| !s.requires_approval));
}

#[test]
fn test_workflow_definition_approval_gate_always_requires_approval() {
    let yaml = r#"
steps:
  - name: gate
    kind: approval_gate
"#;
    let steps = parse_workflow_definition(yaml).expect("valid definition parses");
    assert!(
        steps[0].requires_approval,
        "an approval_gate step must require approval even when the document omits the flag"
    );
}

#[test]
fn test_workflow_definition_explicit_order_overrides_document_order() {
    let yaml = r#"
steps:
  - name: second
    kind: build
    order: 2
  - name: first
    kind: test
    order: 1
"#;
    let steps = parse_workflow_definition(yaml).expect("valid definition parses");
    assert_eq!(steps[0].name, "first");
    assert_eq!(steps[1].name, "second");
}

#[test]
fn test_workflow_definition_rejects_invalid_documents() {
    // Empty.
    assert!(parse_workflow_definition("   ").is_err());

    // Not YAML / wrong shape.
    assert!(parse_workflow_definition("this: is: not: valid").is_err());

    // Missing the steps key entirely — must NOT silently yield a default pipeline.
    assert!(parse_workflow_definition("workflow:\n  on: push\n").is_err());

    // Declares no steps.
    assert!(parse_workflow_definition("steps: []\n").is_err());

    // Unknown step kind.
    assert!(parse_workflow_definition("steps:\n  - name: x\n    kind: teleport\n").is_err());

    // Empty step name.
    assert!(parse_workflow_definition("steps:\n  - name: '  '\n    kind: test\n").is_err());

    // Ambiguous ordering.
    let dup = "steps:\n  - name: a\n    kind: test\n    order: 1\n  - name: b\n    kind: build\n    order: 1\n";
    assert!(parse_workflow_definition(dup).is_err());
}
