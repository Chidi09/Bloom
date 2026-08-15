use bloom_cloud_backend::apps::observability::permissions::{
    OrganizationPermission, OrganizationRole,
};

#[test]
fn test_observability_permission_roles() {
    let viewer_perm = OrganizationPermission::viewer();
    assert_eq!(viewer_perm.min_role, OrganizationRole::Viewer);

    // Verify role hierarchy
    assert!(OrganizationRole::Viewer <= OrganizationRole::Developer);
    assert!(OrganizationRole::Developer <= OrganizationRole::ReleaseManager);
    assert!(OrganizationRole::ReleaseManager <= OrganizationRole::Admin);
    assert!(OrganizationRole::Admin <= OrganizationRole::Owner);

    // Verify role string conversions
    assert_eq!(OrganizationRole::Viewer.as_str(), "viewer");
    assert_eq!(OrganizationRole::Developer.as_str(), "developer");
    assert_eq!(OrganizationRole::ReleaseManager.as_str(), "release_manager");
    assert_eq!(OrganizationRole::Admin.as_str(), "admin");
    assert_eq!(OrganizationRole::Owner.as_str(), "owner");
}
