use bloom_cloud_backend::apps::git_connections::permissions::{
    CurrentOrganizationId, CurrentOrganizationPublicId, CurrentOrganizationRole,
    OrganizationPermission, OrganizationRole,
};

#[test]
fn test_git_connection_permission_levels() {
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
fn test_git_connection_organization_extensions() {
    let org_id = CurrentOrganizationId(404);
    assert_eq!(org_id.0, 404);

    let role_ext = CurrentOrganizationRole("admin".to_string());
    assert_eq!(role_ext.0, "admin");

    let pub_id_ext =
        CurrentOrganizationPublicId("440e8400-e29b-41d4-a716-446655440000".to_string());
    assert_eq!(pub_id_ext.0, "440e8400-e29b-41d4-a716-446655440000");
}

#[test]
fn test_git_connection_role_matrix_rules() {
    let viewer = OrganizationRole::Viewer;
    let developer = OrganizationRole::Developer;
    let release_manager = OrganizationRole::ReleaseManager;
    let admin = OrganizationRole::Admin;
    let owner = OrganizationRole::Owner;

    // Read access requires Viewer
    assert!(viewer >= OrganizationRole::Viewer);
    assert!(developer >= OrganizationRole::Viewer);
    assert!(release_manager >= OrganizationRole::Viewer);
    assert!(admin >= OrganizationRole::Viewer);
    assert!(owner >= OrganizationRole::Viewer);

    // Create / Delete requires Admin (per apps/git_connections.md)
    assert!(viewer < OrganizationRole::Admin);
    assert!(developer < OrganizationRole::Admin);
    assert!(release_manager < OrganizationRole::Admin);
    assert!(admin >= OrganizationRole::Admin);
    assert!(owner >= OrganizationRole::Admin);
}
