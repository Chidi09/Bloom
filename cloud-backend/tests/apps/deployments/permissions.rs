use bloom_cloud_backend::apps::deployments::permissions::{
    CurrentOrganizationId, CurrentOrganizationPublicId, CurrentOrganizationRole,
    OrganizationPermission, OrganizationRole,
};

#[test]
fn test_deployments_permission_matrix() {
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

    // Deployments GET endpoints are accessible to Viewer and above
    assert!(OrganizationRole::Viewer >= viewer.min_role);
    assert!(OrganizationRole::Developer >= viewer.min_role);
    assert!(OrganizationRole::ReleaseManager >= viewer.min_role);
    assert!(OrganizationRole::Admin >= viewer.min_role);
    assert!(OrganizationRole::Owner >= viewer.min_role);

    // Non-production deployment POST requires Developer
    assert!(OrganizationRole::Viewer < dev.min_role);
    assert!(OrganizationRole::Developer >= dev.min_role);
    assert!(OrganizationRole::ReleaseManager >= dev.min_role);

    // Production deployment POST requires ReleaseManager (Phase 5 exit gate)
    assert!(OrganizationRole::Viewer < rm.min_role);
    assert!(OrganizationRole::Developer < rm.min_role);
    assert!(OrganizationRole::ReleaseManager >= rm.min_role);
    assert!(OrganizationRole::Admin >= rm.min_role);
    assert!(OrganizationRole::Owner >= rm.min_role);
}

#[test]
fn test_deployments_organization_extensions() {
    let org_id = CurrentOrganizationId(100);
    assert_eq!(org_id.0, 100);

    let role_ext = CurrentOrganizationRole("developer".to_string());
    assert_eq!(role_ext.0, "developer");

    let pub_id_ext =
        CurrentOrganizationPublicId("11111111-2222-3333-4444-555555555555".to_string());
    assert_eq!(pub_id_ext.0, "11111111-2222-3333-4444-555555555555");
}
