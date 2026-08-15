use bloom_cloud_backend::apps::webhosting::permissions::{
    CurrentOrganizationId, CurrentOrganizationPublicId, CurrentOrganizationRole,
    OrganizationPermission, OrganizationRole,
};

#[test]
fn test_webhosting_permission_matrix() {
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

    // Deployments and domains are readable by Viewer and above (GET endpoints).
    assert!(OrganizationRole::Viewer >= viewer.min_role);
    assert!(OrganizationRole::Developer >= viewer.min_role);
    assert!(OrganizationRole::ReleaseManager >= viewer.min_role);
    assert!(OrganizationRole::Admin >= viewer.min_role);
    assert!(OrganizationRole::Owner >= viewer.min_role);

    // Preview deployments and custom domain CRUD require Developer.
    assert!(OrganizationRole::Viewer < dev.min_role);
    assert!(OrganizationRole::Developer >= dev.min_role);
    assert!(OrganizationRole::ReleaseManager >= dev.min_role);

    // Production deployments require Release Manager or above (Phase 4 exit gate).
    assert!(OrganizationRole::Viewer < rm.min_role);
    assert!(OrganizationRole::Developer < rm.min_role);
    assert!(OrganizationRole::ReleaseManager >= rm.min_role);
    assert!(OrganizationRole::Admin >= rm.min_role);
    assert!(OrganizationRole::Owner >= rm.min_role);
}

#[test]
fn test_webhosting_organization_extensions() {
    let org_id = CurrentOrganizationId(42);
    assert_eq!(org_id.0, 42);

    let role_ext = CurrentOrganizationRole("release_manager".to_string());
    assert_eq!(role_ext.0, "release_manager");

    let pub_id_ext =
        CurrentOrganizationPublicId("550e8400-e29b-41d4-a716-446655440000".to_string());
    assert_eq!(pub_id_ext.0, "550e8400-e29b-41d4-a716-446655440000");
}
