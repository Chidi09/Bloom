use bloom_cloud_backend::apps::organizations::models::{
    Organization, OrganizationInvite, UserOrganizationMembership,
};

#[test]
fn test_organizations_models_metadata() {
    let org_meta = Organization::meta();
    assert_eq!(org_meta.app_label, "organizations");
    assert_eq!(org_meta.table_name, "organizations_organization");

    let slug_field = org_meta
        .fields
        .iter()
        .find(|f| f.name == "slug")
        .expect("slug field must exist on Organization");
    assert!(slug_field.unique, "slug must be unique on Organization");
    assert_eq!(slug_field.max_length, Some(64));

    let public_id_field = org_meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Organization");
    assert_eq!(public_id_field.max_length, Some(36));

    let membership_meta = UserOrganizationMembership::meta();
    assert_eq!(membership_meta.app_label, "organizations");
    assert_eq!(
        membership_meta.table_name,
        "organizations_userorganizationmembership"
    );

    let user_id_field = membership_meta
        .fields
        .iter()
        .find(|f| f.name == "user_id")
        .expect("user_id field must exist on UserOrganizationMembership");
    assert!(user_id_field.db_index, "user_id must be indexed");

    let org_id_field = membership_meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on UserOrganizationMembership");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    let invite_meta = OrganizationInvite::meta();
    assert_eq!(invite_meta.app_label, "organizations");
    assert_eq!(invite_meta.table_name, "organizations_organizationinvite");

    let token_field = invite_meta
        .fields
        .iter()
        .find(|f| f.name == "token")
        .expect("token field must exist on OrganizationInvite");
    assert!(
        token_field.unique,
        "token must be unique on OrganizationInvite"
    );
    assert_eq!(token_field.max_length, Some(128));
}
