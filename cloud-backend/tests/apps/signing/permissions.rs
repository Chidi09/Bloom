use bloom_cloud_backend::apps::signing::permissions::{
    CurrentOrganizationId, CurrentOrganizationPublicId, CurrentOrganizationRole,
    OrganizationPermission, OrganizationRole,
};

#[test]
fn test_signing_permission_role_matrix() {
    let viewer = OrganizationRole::Viewer;
    let developer = OrganizationRole::Developer;
    let release_manager = OrganizationRole::ReleaseManager;
    let admin = OrganizationRole::Admin;
    let owner = OrganizationRole::Owner;

    // View signing metadata (min_role = Viewer)
    assert!(viewer >= OrganizationRole::Viewer);
    assert!(developer >= OrganizationRole::Viewer);
    assert!(release_manager >= OrganizationRole::Viewer);
    assert!(admin >= OrganizationRole::Viewer);
    assert!(owner >= OrganizationRole::Viewer);

    // Upload / Delete signing materials (min_role = ReleaseManager)
    assert!((viewer < OrganizationRole::ReleaseManager));
    assert!((developer < OrganizationRole::ReleaseManager));
    assert!(release_manager >= OrganizationRole::ReleaseManager);
    assert!(admin >= OrganizationRole::ReleaseManager);
    assert!(owner >= OrganizationRole::ReleaseManager);
}

#[test]
fn test_signing_permission_helpers() {
    let rel_mgr_perm = OrganizationPermission::release_manager();
    assert_eq!(rel_mgr_perm.min_role, OrganizationRole::ReleaseManager);

    let viewer_perm = OrganizationPermission::viewer();
    assert_eq!(viewer_perm.min_role, OrganizationRole::Viewer);
}

#[test]
fn test_signing_organization_context_extensions() {
    let org_id = CurrentOrganizationId(108);
    assert_eq!(org_id.0, 108);

    let role_ext = CurrentOrganizationRole("release_manager".to_string());
    assert_eq!(role_ext.0, "release_manager");

    let pub_id_ext =
        CurrentOrganizationPublicId("440e8400-e29b-41d4-a716-446655440000".to_string());
    assert_eq!(pub_id_ext.0, "440e8400-e29b-41d4-a716-446655440000");
}
