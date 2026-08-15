use bloom_cloud_backend::apps::accounts::permissions::CurrentOrganizationId;
use bloom_cloud_backend::apps::artifacts::permissions::{
    CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};

#[test]
fn test_artifact_permission_matrix() {
    let viewer = OrganizationPermission::viewer();
    assert_eq!(viewer.min_role, OrganizationRole::Viewer);

    let dev = OrganizationPermission::developer();
    assert_eq!(dev.min_role, OrganizationRole::Developer);

    let rm = OrganizationPermission::release_manager();
    assert_eq!(rm.min_role, OrganizationRole::ReleaseManager);

    let admin = OrganizationPermission::admin();
    assert_eq!(admin.min_role, OrganizationRole::Admin);

    let owner = OrganizationPermission::owner();
    assert_eq!(owner.min_role, OrganizationRole::Owner);

    // Artifacts are readable by Viewer and above (GET endpoints require viewer()).
    assert!(OrganizationRole::Viewer >= viewer.min_role);
    assert!(OrganizationRole::Developer >= viewer.min_role);
    assert!(OrganizationRole::Owner >= viewer.min_role);

    // Viewer is not permitted to anything stronger.
    assert!((OrganizationRole::Viewer < dev.min_role));
}

#[test]
fn test_artifact_organization_extensions() {
    let org_id = CurrentOrganizationId(100);
    assert_eq!(org_id.0, 100);

    let role_ext = CurrentOrganizationRole("viewer".to_string());
    assert_eq!(role_ext.0, "viewer");

    let pub_id_ext =
        CurrentOrganizationPublicId("550e8400-e29b-41d4-a716-446655440000".to_string());
    assert_eq!(pub_id_ext.0, "550e8400-e29b-41d4-a716-446655440000");
}

#[test]
fn test_job_token_minting_and_verification_happy_path() {
    use bloom_cloud_backend::apps::artifacts::permissions::{mint_job_token, verify_job_token};

    let build_id = "build-1111-2222";
    let org_id = "org-3333-4444";
    let signing_key = b"test-master-secret-key-12345678";

    let token = mint_job_token(build_id, org_id, 3600, signing_key);
    assert_eq!(token.claims().build_id, build_id);
    assert_eq!(token.claims().organization_id, org_id);

    // Verify against matching scope
    let verified = verify_job_token(token.as_str(), Some(build_id), Some(org_id), signing_key);
    assert!(verified.is_ok());
    let claims = verified.unwrap();
    assert_eq!(claims.build_id, build_id);
    assert_eq!(claims.organization_id, org_id);

    // Verify without explicit scope (unscoped verification)
    let verified_unscoped = verify_job_token(token.as_str(), None, None, signing_key);
    assert!(verified_unscoped.is_ok());
}

#[test]
fn test_job_token_rejected_for_wrong_build() {
    use bloom_cloud_backend::apps::artifacts::permissions::{mint_job_token, verify_job_token};

    let build_a = "build-aaaa";
    let build_b = "build-bbbb";
    let org_id = "org-1111";
    let signing_key = b"test-master-secret-key-12345678";

    let token = mint_job_token(build_a, org_id, 3600, signing_key);

    // Valid token for build A is REJECTED for build B
    let result = verify_job_token(token.as_str(), Some(build_b), Some(org_id), signing_key);
    assert!(result.is_err());
}

#[test]
fn test_job_token_rejected_for_wrong_organization() {
    use bloom_cloud_backend::apps::artifacts::permissions::{mint_job_token, verify_job_token};

    let build_id = "build-1111";
    let org_x = "org-xxxx";
    let org_y = "org-yyyy";
    let signing_key = b"test-master-secret-key-12345678";

    let token = mint_job_token(build_id, org_x, 3600, signing_key);

    // Valid token for org X is REJECTED for org Y
    let result = verify_job_token(token.as_str(), Some(build_id), Some(org_y), signing_key);
    assert!(result.is_err());
}

#[test]
fn test_job_token_rejected_when_expired() {
    use bloom_cloud_backend::apps::artifacts::permissions::{mint_job_token, verify_job_token};

    let build_id = "build-1111";
    let org_id = "org-1111";
    let signing_key = b"test-master-secret-key-12345678";

    // Mint token with negative TTL (already expired in the past)
    let token = mint_job_token(build_id, org_id, -10, signing_key);

    let result = verify_job_token(token.as_str(), Some(build_id), Some(org_id), signing_key);
    assert!(result.is_err(), "Expired token must be rejected");
}

#[test]
fn test_job_token_rejected_when_tampered() {
    use bloom_cloud_backend::apps::artifacts::permissions::{mint_job_token, verify_job_token};

    let build_id = "build-1111";
    let org_id = "org-1111";
    let signing_key = b"test-master-secret-key-12345678";

    let token = mint_job_token(build_id, org_id, 3600, signing_key);
    let token_raw = token.as_str();

    // 1. Tamper with the signature portion
    let mut parts: Vec<&str> = token_raw.split(':').collect();
    let tampered_sig = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    parts[4] = tampered_sig;
    let tampered_token = parts.join(":");
    let result = verify_job_token(&tampered_token, Some(build_id), Some(org_id), signing_key);
    assert!(result.is_err(), "Tampered signature must be rejected");

    // 2. Tamper with the build_id in payload while keeping signature
    let mut parts: Vec<&str> = token_raw.split(':').collect();
    parts[0] = "build-tampered";
    let tampered_token = parts.join(":");
    let result = verify_job_token(&tampered_token, None, None, signing_key);
    assert!(result.is_err(), "Tampered payload must be rejected");

    // 3. Malformed token structure (fewer or more parts)
    assert!(verify_job_token("malformed:token", None, None, signing_key).is_err());
    assert!(verify_job_token("", None, None, signing_key).is_err());

    // 4. Token signed with a different key
    let different_key = b"completely-different-signing-key";
    let result = verify_job_token(token_raw, Some(build_id), Some(org_id), different_key);
    assert!(result.is_err(), "Wrong signing key must be rejected");
}

#[test]
fn test_job_token_redacts_secret_in_debug_and_display() {
    use bloom_cloud_backend::apps::artifacts::permissions::mint_job_token;

    let build_id = "build-123";
    let org_id = "org-456";
    let signing_key = b"test-key";

    let token = mint_job_token(build_id, org_id, 3600, signing_key);
    let raw_token_str = token.as_str();

    // Debug output must redact raw token string
    let debug_str = format!("{token:?}");
    assert!(
        !debug_str.contains(raw_token_str),
        "Raw token must not appear in Debug"
    );
    assert!(debug_str.contains("[REDACTED]"));

    // Display output must redact raw token string
    let display_str = format!("{token}");
    assert!(
        !display_str.contains(raw_token_str),
        "Raw token must not appear in Display"
    );
    assert_eq!(display_str, "[REDACTED_JOB_TOKEN]");
}
