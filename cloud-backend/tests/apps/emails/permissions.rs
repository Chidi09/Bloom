use bloom_cloud_backend::apps::emails::errors::EmailsError;
use bloom_cloud_backend::apps::emails::permissions::{
    require_staff, CurrentOrganizationId, CurrentOrganizationPublicId, CurrentOrganizationRole,
    OrganizationPermission, OrganizationRole,
};
use djangors_auth::User;

#[test]
fn test_emails_role_permissions_for_logs() {
    let admin_perm = OrganizationPermission::admin();
    assert_eq!(admin_perm.min_role, OrganizationRole::Admin);

    // Email logs require Admin or Owner
    assert!(OrganizationRole::Viewer < admin_perm.min_role);
    assert!(OrganizationRole::Developer < admin_perm.min_role);
    assert!(OrganizationRole::ReleaseManager < admin_perm.min_role);
    assert!(OrganizationRole::Admin >= admin_perm.min_role);
    assert!(OrganizationRole::Owner >= admin_perm.min_role);
}

#[test]
fn test_require_staff_privilege_enforcement() {
    let regular_user = User {
        id: 1,
        username: "developer".to_string(),
        email: "dev@bloom.dev".to_string(),
        password: "hash".to_string(),
        is_active: true,
        is_staff: false,
        is_superuser: false,
        date_joined: chrono::Utc::now(),
        last_login: None,
    };

    assert_eq!(
        require_staff(&regular_user),
        Err(EmailsError::StaffRequired)
    );

    let staff_user = User {
        is_staff: true,
        ..regular_user.clone()
    };
    assert_eq!(require_staff(&staff_user), Ok(()));

    let superuser = User {
        is_superuser: true,
        ..regular_user.clone()
    };
    assert_eq!(require_staff(&superuser), Ok(()));
}

#[test]
fn test_organization_extensions() {
    let org_id = CurrentOrganizationId(101);
    assert_eq!(org_id.0, 101);

    let role_ext = CurrentOrganizationRole("admin".to_string());
    assert_eq!(role_ext.0, "admin");

    let pub_id_ext =
        CurrentOrganizationPublicId("550e8400-e29b-41d4-a716-446655440000".to_string());
    assert_eq!(pub_id_ext.0, "550e8400-e29b-41d4-a716-446655440000");
}
