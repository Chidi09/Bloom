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
