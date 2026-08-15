use bloom_cloud_backend::apps::billing::permissions::{
    CurrentOrganizationId, CurrentOrganizationPublicId, CurrentOrganizationRole,
    OrganizationPermission, OrganizationRole,
};

#[test]
fn test_billing_role_hierarchy_and_permissions() {
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

    // Viewing billing information (GET endpoints) is accessible to Viewer and above
    assert!(OrganizationRole::Viewer >= viewer_perm.min_role);
    assert!(OrganizationRole::Developer >= viewer_perm.min_role);
    assert!(OrganizationRole::ReleaseManager >= viewer_perm.min_role);
    assert!(OrganizationRole::Admin >= viewer_perm.min_role);
    assert!(OrganizationRole::Owner >= viewer_perm.min_role);

    // Modifying subscriptions (POST /billing/subscribe, POST /billing/cancel) requires Admin or Owner
    assert!(OrganizationRole::Viewer < admin_perm.min_role);
    assert!(OrganizationRole::Developer < admin_perm.min_role);
    assert!(OrganizationRole::ReleaseManager < admin_perm.min_role);
    assert!(OrganizationRole::Admin >= admin_perm.min_role);
    assert!(OrganizationRole::Owner >= admin_perm.min_role);
}

#[test]
fn test_billing_organization_extensions() {
    let org_id = CurrentOrganizationId(42);
    assert_eq!(org_id.0, 42);

    let role_ext = CurrentOrganizationRole("admin".to_string());
    assert_eq!(role_ext.0, "admin");

    let pub_id_ext =
        CurrentOrganizationPublicId("550e8400-e29b-41d4-a716-446655440000".to_string());
    assert_eq!(pub_id_ext.0, "550e8400-e29b-41d4-a716-446655440000");
}
