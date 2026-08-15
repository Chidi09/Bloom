use bloom_cloud_backend::apps::accounts::permissions::CurrentOrganizationId;
use bloom_cloud_backend::apps::builds::permissions::{
    CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};

#[test]
fn test_builds_permissions_matrix() {
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

    // Phase 3 gate verification:
    // Developer can create builds / cancel (min_role: Developer)
    assert!(OrganizationRole::Developer >= dev.min_role);
    assert!(OrganizationRole::Admin >= dev.min_role);
    assert!(OrganizationRole::Owner >= dev.min_role);

    // Viewer CANNOT create builds (fails min_role: Developer)
    assert!((OrganizationRole::Viewer < dev.min_role));

    // Viewer CAN read build records (satisfies min_role: Viewer)
    assert!(OrganizationRole::Viewer >= viewer.min_role);
    assert!(OrganizationRole::Developer >= viewer.min_role);
}

#[test]
fn test_builds_scoping_extensions() {
    let org_id_ext = CurrentOrganizationId(12345);
    assert_eq!(org_id_ext.0, 12345);

    let org_pub_id =
        CurrentOrganizationPublicId("550e8400-e29b-41d4-a716-446655440000".to_string());
    assert_eq!(org_pub_id.0, "550e8400-e29b-41d4-a716-446655440000");

    let role_ext = CurrentOrganizationRole("developer".to_string());
    assert_eq!(role_ext.0, "developer");
}
