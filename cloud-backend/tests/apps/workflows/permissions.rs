use bloom_cloud_backend::apps::accounts::permissions::CurrentOrganizationId;
use bloom_cloud_backend::apps::workflows::permissions::{
    CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};

#[test]
fn test_workflows_permissions_matrix() {
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

    // Role hierarchy tests:
    // Developer can create workflow definitions and trigger runs
    assert!(OrganizationRole::Developer >= dev.min_role);
    assert!(OrganizationRole::ReleaseManager >= dev.min_role);
    assert!(OrganizationRole::Admin >= dev.min_role);
    assert!(OrganizationRole::Owner >= dev.min_role);

    // Viewer CANNOT create workflows or trigger runs
    assert!(OrganizationRole::Viewer < dev.min_role);

    // Approval gate requires ReleaseManager or above
    assert!(OrganizationRole::ReleaseManager >= rm.min_role);
    assert!(OrganizationRole::Admin >= rm.min_role);
    assert!(OrganizationRole::Owner >= rm.min_role);

    // Developer and Viewer CANNOT approve gates
    assert!(OrganizationRole::Developer < rm.min_role);
    assert!(OrganizationRole::Viewer < rm.min_role);

    // Viewer CAN view workflows and runs
    assert!(OrganizationRole::Viewer >= viewer.min_role);
}

#[test]
fn test_workflows_scoping_extensions() {
    let org_id_ext = CurrentOrganizationId(42);
    assert_eq!(org_id_ext.0, 42);

    let org_pub_id =
        CurrentOrganizationPublicId("550e8400-e29b-41d4-a716-446655440000".to_string());
    assert_eq!(org_pub_id.0, "550e8400-e29b-41d4-a716-446655440000");

    let role_ext = CurrentOrganizationRole("release_manager".to_string());
    assert_eq!(role_ext.0, "release_manager");
}
