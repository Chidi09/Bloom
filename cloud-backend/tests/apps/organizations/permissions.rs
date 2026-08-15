use bloom_cloud_backend::apps::accounts::permissions::CurrentOrganizationId;
use bloom_cloud_backend::apps::organizations::permissions::{
    CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};

#[test]
fn test_organization_permission_levels() {
    let viewer_perm = OrganizationPermission::viewer();
    assert_eq!(viewer_perm.min_role, OrganizationRole::Viewer);

    let dev_perm = OrganizationPermission::developer();
    assert_eq!(dev_perm.min_role, OrganizationRole::Developer);

    let rm_perm = OrganizationPermission::release_manager();
    assert_eq!(rm_perm.min_role, OrganizationRole::ReleaseManager);

    let admin_perm = OrganizationPermission::admin();
    assert_eq!(admin_perm.min_role, OrganizationRole::Admin);

    let owner_perm = OrganizationPermission::owner();
    assert_eq!(owner_perm.min_role, OrganizationRole::Owner);
}

#[test]
fn test_organization_extensions() {
    let org_id = CurrentOrganizationId(42);
    assert_eq!(org_id.0, 42);

    let role_ext = CurrentOrganizationRole("admin".to_string());
    assert_eq!(role_ext.0, "admin");

    let pub_id_ext =
        CurrentOrganizationPublicId("550e8400-e29b-41d4-a716-446655440000".to_string());
    assert_eq!(pub_id_ext.0, "550e8400-e29b-41d4-a716-446655440000");
}

#[test]
fn test_role_comparisons_and_matrix() {
    let viewer = OrganizationRole::Viewer;
    let dev = OrganizationRole::Developer;
    let rm = OrganizationRole::ReleaseManager;
    let admin = OrganizationRole::Admin;
    let owner = OrganizationRole::Owner;

    // Viewer satisfies only viewer
    assert!(viewer >= OrganizationRole::Viewer);
    assert!((viewer < OrganizationRole::Developer));
    assert!((viewer < OrganizationRole::Admin));

    // Developer satisfies viewer and developer
    assert!(dev >= OrganizationRole::Viewer);
    assert!(dev >= OrganizationRole::Developer);
    assert!((dev < OrganizationRole::ReleaseManager));
    assert!((dev < OrganizationRole::Admin));

    // Release manager satisfies viewer, developer, release manager
    assert!(rm >= OrganizationRole::Viewer);
    assert!(rm >= OrganizationRole::Developer);
    assert!(rm >= OrganizationRole::ReleaseManager);
    assert!((rm < OrganizationRole::Admin));

    // Admin satisfies all except owner
    assert!(admin >= OrganizationRole::Viewer);
    assert!(admin >= OrganizationRole::Developer);
    assert!(admin >= OrganizationRole::ReleaseManager);
    assert!(admin >= OrganizationRole::Admin);
    assert!((admin < OrganizationRole::Owner));

    // Owner satisfies all
    assert!(owner >= OrganizationRole::Viewer);
    assert!(owner >= OrganizationRole::Developer);
    assert!(owner >= OrganizationRole::ReleaseManager);
    assert!(owner >= OrganizationRole::Admin);
    assert!(owner >= OrganizationRole::Owner);
}
