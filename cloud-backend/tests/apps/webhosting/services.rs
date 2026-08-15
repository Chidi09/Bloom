use bytes::Bytes;

use bloom_cloud_backend::apps::webhosting::models::WebDeployment;
use bloom_cloud_backend::apps::webhosting::services::{
    build_preview_url, build_production_url, build_web_storage_prefix, can_transition,
    compute_challenge_hostname, compute_required_dns_records, generate_verification_token,
    is_apex_domain, sanitize_branch_slug, validate_certificate_status, validate_domain,
    validate_target, DEFAULT_APEX_DOMAIN, DEFAULT_EDGE_A_RECORD_IP, VALID_CERTIFICATE_STATUSES,
    VALID_DEPLOYMENT_STATUSES, VALID_TARGETS,
};
use bloom_cloud_backend::infra::caddy::{
    build_dns_challenge_automation_policy, build_verified_custom_domain_site_block, CaddyError,
};
use bloom_cloud_backend::infra::crypto::Crypto;
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
    assert!(validate_domain("*.acme.co.uk").is_ok());

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
fn test_is_apex_domain() {
    assert!(is_apex_domain("example.com"));
    assert!(is_apex_domain("bloom.dev"));
    assert!(is_apex_domain("company.co.uk"));
    assert!(is_apex_domain("startup.com.ng"));

    assert!(!is_apex_domain("app.example.com"));
    assert!(!is_apex_domain("dashboard.bloom.dev"));
    assert!(!is_apex_domain("api.company.co.uk"));
}

#[test]
fn test_challenge_hostname_and_required_records_computation() {
    let token = "bloom_verify_token_123";
    let challenge = compute_challenge_hostname("app.mysite.com");
    assert_eq!(challenge, "_bloom-challenge.app.mysite.com");

    let wildcard_challenge = compute_challenge_hostname("*.mysite.com");
    assert_eq!(wildcard_challenge, "_bloom-challenge.mysite.com");

    // Subdomain records
    let sub_records = compute_required_dns_records(
        "app.mysite.com",
        token,
        "flutter-store",
        "retail",
        Some("bloomcloud.dev"),
    );
    assert_eq!(sub_records.len(), 2);
    assert_eq!(sub_records[0].record_type, "TXT");
    assert_eq!(sub_records[0].host, "_bloom-challenge.app.mysite.com");
    assert_eq!(sub_records[0].value, token);
    assert_eq!(sub_records[1].record_type, "CNAME");
    assert_eq!(sub_records[1].host, "app.mysite.com");
    assert_eq!(sub_records[1].value, "flutter-store-retail.bloomcloud.dev");

    // Apex domain records
    let apex_records = compute_required_dns_records(
        "mysite.com",
        token,
        "flutter-store",
        "retail",
        Some("bloomcloud.dev"),
    );
    assert_eq!(apex_records.len(), 3);
    assert_eq!(apex_records[0].record_type, "TXT");
    assert_eq!(apex_records[0].host, "_bloom-challenge.mysite.com");
    assert_eq!(apex_records[1].record_type, "A");
    assert_eq!(apex_records[1].value, DEFAULT_EDGE_A_RECORD_IP);
    assert_eq!(apex_records[2].record_type, "CNAME");
    assert_eq!(apex_records[2].value, "flutter-store-retail.bloomcloud.dev");
}

#[test]
fn test_generate_verification_token() {
    let token1 = generate_verification_token();
    let token2 = generate_verification_token();
    assert!(token1.starts_with("bloom_verify_"));
    assert!(token2.starts_with("bloom_verify_"));
    assert_ne!(token1, token2);
}

#[test]
fn test_constant_time_token_comparison_near_miss() {
    let expected = "bloom_verify_abcd1234efgh5678";
    let identical = "bloom_verify_abcd1234efgh5678";
    let near_miss = "bloom_verify_abcd1234efgh5679"; // Last char differs
    let different_len = "bloom_verify_abcd1234efgh56789";

    assert!(Crypto::constant_time_eq_str(expected, identical));
    assert!(!Crypto::constant_time_eq_str(expected, near_miss));
    assert!(!Crypto::constant_time_eq_str(expected, different_len));
}

#[test]
fn test_security_rule_unverified_domain_never_reaches_caddy() {
    let site_id = "bloom-domain-123";
    let domain = "unverified-site.com";
    let storage_prefix = "orgs/1/projects/2/apps/3/custom_domains/123";

    // Attempting to build a site block with is_verified: false MUST fail with SecurityViolation
    let result = build_verified_custom_domain_site_block(site_id, domain, storage_prefix, false);

    assert!(matches!(result, Err(CaddyError::SecurityViolation(_))));
    if let Err(CaddyError::SecurityViolation(msg)) = result {
        assert!(msg.contains("Security rule violation"));
        assert!(msg.contains("not verified"));
    }

    // Verified domain succeeds
    let verified_result =
        build_verified_custom_domain_site_block(site_id, domain, storage_prefix, true);
    assert!(verified_result.is_ok());
    let site_block = verified_result.unwrap();
    assert_eq!(site_block.id, site_id);
    assert_eq!(
        site_block.r#match.unwrap()[0].host.as_ref().unwrap(),
        &vec![domain.to_string()]
    );
}

#[test]
fn test_dns_challenge_automation_policy_builder() {
    let policy = build_dns_challenge_automation_policy(
        "*.example.com",
        Some("cf_token_123"),
        Some("ops@bloom.sh"),
    );

    let subjects = policy.subjects.expect("subjects configured");
    assert_eq!(subjects, vec!["*.example.com"]);

    let issuers = policy.issuers.expect("issuers configured");
    assert_eq!(issuers.len(), 1);
    assert_eq!(issuers[0].module, "acme");
    assert_eq!(issuers[0].email, Some("ops@bloom.sh".to_string()));

    let challenges = issuers[0].challenges.as_ref().expect("challenges");
    let dns_challenge = challenges.dns.as_ref().expect("dns challenge");
    assert_eq!(dns_challenge.provider.name, "cloudflare");
    assert_eq!(
        dns_challenge.provider.api_token,
        Some("cf_token_123".to_string())
    );
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
        &["pending", "issuing", "active", "failed"]
    );
    assert!(validate_certificate_status("pending").is_ok());
    assert!(validate_certificate_status("issuing").is_ok());
    assert!(validate_certificate_status("active").is_ok());
    assert!(validate_certificate_status("failed").is_ok());
    assert!(validate_certificate_status("expired").is_err());
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
