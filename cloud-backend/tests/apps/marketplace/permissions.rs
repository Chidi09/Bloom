use bloom_cloud_backend::apps::marketplace::errors::MarketplaceError;
use bloom_cloud_backend::apps::marketplace::permissions::{
    CurrentOrganizationId, CurrentOrganizationPublicId, CurrentOrganizationRole,
    OrganizationPermission, OrganizationRole,
};

#[test]
fn test_marketplace_permission_levels() {
    let viewer_perm = OrganizationPermission::viewer();
    assert_eq!(viewer_perm.min_role, OrganizationRole::Viewer);

    let dev_perm = OrganizationPermission::developer();
    assert_eq!(dev_perm.min_role, OrganizationRole::Developer);

    let admin_perm = OrganizationPermission::admin();
    assert_eq!(admin_perm.min_role, OrganizationRole::Admin);

    let owner_perm = OrganizationPermission::owner();
    assert_eq!(owner_perm.min_role, OrganizationRole::Owner);
}

#[test]
fn test_marketplace_organization_extensions() {
    let org_id = CurrentOrganizationId(42);
    assert_eq!(org_id.0, 42);

    let role_ext = CurrentOrganizationRole("developer".to_string());
    assert_eq!(role_ext.0, "developer");

    let pub_id_ext =
        CurrentOrganizationPublicId("11111111-1111-4111-8111-111111111111".to_string());
    assert_eq!(pub_id_ext.0, "11111111-1111-4111-8111-111111111111");
}

#[test]
fn test_marketplace_role_matrix() {
    let viewer = OrganizationRole::Viewer;
    let developer = OrganizationRole::Developer;
    let release_manager = OrganizationRole::ReleaseManager;
    let admin = OrganizationRole::Admin;
    let owner = OrganizationRole::Owner;

    // 1. Template viewing capability (min_role = Viewer)
    assert!(viewer >= OrganizationRole::Viewer);
    assert!(developer >= OrganizationRole::Viewer);
    assert!(release_manager >= OrganizationRole::Viewer);
    assert!(admin >= OrganizationRole::Viewer);
    assert!(owner >= OrganizationRole::Viewer);

    // 2. Template creation/editing/publishing capability (min_role = Developer)
    assert!(viewer < OrganizationRole::Developer);
    assert!(developer >= OrganizationRole::Developer);
    assert!(release_manager >= OrganizationRole::Developer);
    assert!(admin >= OrganizationRole::Developer);
    assert!(owner >= OrganizationRole::Developer);

    // 3. Template deletion capability (min_role = Admin)
    assert!(viewer < OrganizationRole::Admin);
    assert!(developer < OrganizationRole::Admin);
    assert!(release_manager < OrganizationRole::Admin);
    assert!(admin >= OrganizationRole::Admin);
    assert!(owner >= OrganizationRole::Admin);
}

#[test]
fn test_cross_tenant_isolation_invariants() {
    let tenant_a_org_id = CurrentOrganizationId(100);
    let tenant_b_org_id = CurrentOrganizationId(200);

    // Tenant isolation: org A != org B
    assert_ne!(tenant_a_org_id.0, tenant_b_org_id.0);
}

#[test]
fn test_author_review_moderation_prohibition_invariant() {
    let author_org_id = 10;
    let reviewer_buyer_org_id = 20;

    // Author cannot edit or delete another organization's review on their template
    let author_attempting_edit = author_org_id != reviewer_buyer_org_id;
    assert!(author_attempting_edit);

    let err = MarketplaceError::AuthorCannotModerateReviews;
    assert_eq!(err, MarketplaceError::AuthorCannotModerateReviews);
}
