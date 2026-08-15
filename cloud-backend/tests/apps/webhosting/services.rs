use bytes::Bytes;

use bloom_cloud_backend::apps::webhosting::models::WebDeployment;
use bloom_cloud_backend::apps::webhosting::services::{
    build_preview_url, build_production_url, build_web_storage_prefix, can_transition,
    sanitize_branch_slug, validate_domain, validate_target, DEFAULT_APEX_DOMAIN,
    VALID_CERTIFICATE_STATUSES, VALID_DEPLOYMENT_STATUSES, VALID_TARGETS,
};
use bloom_cloud_backend::infra::storage::{web_bundle_storage_key, InMemoryStorage, ObjectStorage};

#[test]
fn test_transition_matrix_exhaustive() {
    let statuses = ["deploying", "live", "failed", "rolled_back"];

    // Expected valid transitions:
    // deploying -> live
    // deploying -> failed
    // live -> rolled_back
    // All other transitions must be false (terminal absorbing states).
    for from in &statuses {
        for to in &statuses {
            let allowed = can_transition(from, to);
            match (*from, *to) {
                ("deploying", "live") => assert!(allowed, "deploying -> live must be allowed"),
                ("deploying", "failed") => assert!(allowed, "deploying -> failed must be allowed"),
                ("live", "rolled_back") => {
                    assert!(allowed, "live -> rolled_back must be allowed")
                }
                _ => assert!(
                    !allowed,
                    "Transition from {from} to {to} must NOT be allowed"
                ),
            }
        }
    }
}

#[test]
fn test_preview_url_construction_configured_apex() {
    let url = build_preview_url(
        Some("custom.dev"),
        "feat/cool-login",
        "buyer-app",
        "ecommerce",
    );
    assert_eq!(
        url,
        "https://feat-cool-login-buyer-app-ecommerce.custom.dev"
    );
}

#[test]
fn test_preview_url_construction_unconfigured_apex_fallback() {
    let url = build_preview_url(None, "main", "store", "acme");
    assert_eq!(
        url,
        format!("https://main-store-acme.{DEFAULT_APEX_DOMAIN}")
    );
    assert_eq!(url, "https://main-store-acme.bloomcloud.dev");
}

#[test]
fn test_production_url_construction() {
    let configured = build_production_url(Some("bloomapps.io"), "buyer-app", "ecommerce");
    assert_eq!(configured, "https://buyer-app-ecommerce.bloomapps.io");

    let default_url = build_production_url(None, "buyer-app", "ecommerce");
    assert_eq!(default_url, "https://buyer-app-ecommerce.bloomcloud.dev");
}

#[test]
fn test_branch_slug_sanitization() {
    assert_eq!(sanitize_branch_slug("main"), "main");
    assert_eq!(
        sanitize_branch_slug("feature/user-auth_v2"),
        "feature-user-auth-v2"
    );
    assert_eq!(sanitize_branch_slug("---weird---branch---"), "weird-branch");
    assert_eq!(sanitize_branch_slug(""), "preview");
}

#[test]
fn test_storage_prefix_matches_web_bundle_storage_key_hierarchy() {
    let org_id = "org-123";
    let proj_id = "proj-456";
    let app_id = "app-789";
    let dep_id = "dep-999";
    let file = "index.html";

    let prefix = build_web_storage_prefix(org_id, proj_id, app_id, dep_id);
    let full_key = web_bundle_storage_key(org_id, proj_id, app_id, dep_id, file);

    assert_eq!(
        prefix,
        "orgs/org-123/projects/proj-456/apps/app-789/web/dep-999"
    );
    assert_eq!(full_key, format!("{prefix}/{file}"));
    assert_eq!(
        full_key,
        "orgs/org-123/projects/proj-456/apps/app-789/web/dep-999/index.html"
    );
}

#[test]
fn test_domain_validation() {
    assert!(validate_domain("example.com").is_ok());
    assert_eq!(
        validate_domain("APP.EXAMPLE.COM").unwrap(),
        "app.example.com"
    );
    assert!(validate_domain("my-store.acme.co.uk").is_ok());

    assert!(validate_domain("").is_err());
    assert!(validate_domain("https://example.com").is_err());
    assert!(validate_domain("http://example.com").is_err());
    assert!(validate_domain("example.com/path").is_err());
    assert!(validate_domain(".example.com").is_err());
    assert!(validate_domain("example.com.").is_err());
    assert!(validate_domain("example_domain.com").is_err());
    assert!(validate_domain("nodots").is_err());
}

#[test]
fn test_target_and_constants_validation() {
    assert_eq!(VALID_TARGETS, &["preview", "production"]);
    assert!(validate_target("preview").is_ok());
    assert!(validate_target("production").is_ok());
    assert!(validate_target("staging").is_err());
    assert!(validate_target("").is_err());

    assert_eq!(
        VALID_DEPLOYMENT_STATUSES,
        &["deploying", "live", "failed", "rolled_back"]
    );
    assert_eq!(
        VALID_CERTIFICATE_STATUSES,
        &["pending", "issued", "expired"]
    );
}

#[tokio::test]
async fn test_in_memory_storage_with_web_bundle_key() {
    let storage = InMemoryStorage::new();
    let org_id = "org-1";
    let proj_id = "proj-1";
    let app_id = "app-1";
    let dep_id = "dep-1";

    let key = web_bundle_storage_key(org_id, proj_id, app_id, dep_id, "main.dart.js");
    storage
        .put(
            &key,
            Bytes::from_static(b"console.log('web bundle');"),
            "application/javascript",
        )
        .await
        .expect("upload bundle asset succeeds");

    assert!(storage.exists(&key).await.expect("exists check"));
    let bytes = storage.get(&key).await.expect("download succeeds");
    assert_eq!(bytes, Bytes::from_static(b"console.log('web bundle');"));
}

#[test]
fn test_rollback_selection_order() {
    // Simulates the selection rule: previous_deployment_for_app_and_target
    // picks the most recent deployment where id != current.id and status is live/rolled_back.
    let deployments = vec![
        WebDeployment {
            id: 3,
            public_id: "dep-3".to_string(),
            app_id: djangors_orm::ForeignKey::new(1),
            organization_id: 10,
            environment_id: djangors_orm::ForeignKey::new(2),
            artifact_id: djangors_orm::ForeignKey::new(5),
            release_id: None,
            target: "production".to_string(),
            url: "https://app-proj.bloomcloud.dev".to_string(),
            storage_prefix: "orgs/10/web/dep-3".to_string(),
            status: "live".to_string(),
            metadata: "{}".to_string(),
            deployed_by_id: 1,
            created_at: chrono::Utc::now(),
        },
        WebDeployment {
            id: 2,
            public_id: "dep-2".to_string(),
            app_id: djangors_orm::ForeignKey::new(1),
            organization_id: 10,
            environment_id: djangors_orm::ForeignKey::new(2),
            artifact_id: djangors_orm::ForeignKey::new(4),
            release_id: None,
            target: "production".to_string(),
            url: "https://app-proj.bloomcloud.dev".to_string(),
            storage_prefix: "orgs/10/web/dep-2".to_string(),
            status: "rolled_back".to_string(),
            metadata: "{}".to_string(),
            deployed_by_id: 1,
            created_at: chrono::Utc::now() - chrono::Duration::hours(1),
        },
        WebDeployment {
            id: 1,
            public_id: "dep-1".to_string(),
            app_id: djangors_orm::ForeignKey::new(1),
            organization_id: 10,
            environment_id: djangors_orm::ForeignKey::new(2),
            artifact_id: djangors_orm::ForeignKey::new(3),
            release_id: None,
            target: "production".to_string(),
            url: "https://app-proj.bloomcloud.dev".to_string(),
            storage_prefix: "orgs/10/web/dep-1".to_string(),
            status: "failed".to_string(),
            metadata: "{}".to_string(),
            deployed_by_id: 1,
            created_at: chrono::Utc::now() - chrono::Duration::hours(2),
        },
    ];

    let current_id = 3;
    let prev = deployments
        .into_iter()
        .find(|d| d.id != current_id && (d.status == "live" || d.status == "rolled_back"));

    assert!(prev.is_some());
    let prev = prev.unwrap();
    assert_eq!(prev.id, 2);
    assert_eq!(prev.public_id, "dep-2");
}
