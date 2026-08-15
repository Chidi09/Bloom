use bloom_cloud_backend::apps::accounts::permissions::CurrentOrganizationId;
use bloom_cloud_backend::apps::apps::permissions::{
    CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};

#[test]
fn test_apps_permission_levels() {
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
fn test_apps_organization_extensions() {
    let org_id = CurrentOrganizationId(101);
    assert_eq!(org_id.0, 101);

    let role_ext = CurrentOrganizationRole("developer".to_string());
    assert_eq!(role_ext.0, "developer");

    let pub_id_ext =
        CurrentOrganizationPublicId("6ba7b810-9dad-11d1-80b4-00c04fd430c8".to_string());
    assert_eq!(pub_id_ext.0, "6ba7b810-9dad-11d1-80b4-00c04fd430c8");
}

#[test]
fn test_apps_role_permissions_matrix() {
    // Viewer: read-only access (GET endpoints)
    let viewer = OrganizationRole::Viewer;
    assert!(viewer >= OrganizationRole::Viewer);
    assert!((viewer < OrganizationRole::Developer));
    assert!((viewer < OrganizationRole::Admin));

    // Developer: can create, link, update, delete apps
    let dev = OrganizationRole::Developer;
    assert!(dev >= OrganizationRole::Viewer);
    assert!(dev >= OrganizationRole::Developer);
    assert!((dev < OrganizationRole::Admin));

    // Admin & Owner: full management
    let admin = OrganizationRole::Admin;
    assert!(admin >= OrganizationRole::Viewer);
    assert!(admin >= OrganizationRole::Developer);
    assert!(admin >= OrganizationRole::Admin);

    let owner = OrganizationRole::Owner;
    assert!(owner >= OrganizationRole::Viewer);
    assert!(owner >= OrganizationRole::Developer);
    assert!(owner >= OrganizationRole::Admin);
    assert!(owner >= OrganizationRole::Owner);
}
