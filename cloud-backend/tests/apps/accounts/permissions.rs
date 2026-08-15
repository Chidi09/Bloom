use bloom_cloud_backend::apps::accounts::permissions::{CurrentOrganizationId, CurrentUserId};

#[test]
fn test_accounts_permissions_extension_types() {
    let uid = CurrentUserId(42);
    assert_eq!(uid.0, 42);

    let org_id = CurrentOrganizationId(100);
    assert_eq!(org_id.0, 100);
}
