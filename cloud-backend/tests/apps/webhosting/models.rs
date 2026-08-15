use bloom_cloud_backend::apps::webhosting::models::{CustomDomain, WebDeployment};

#[test]
fn test_web_deployment_model_metadata() {
    let meta = WebDeployment::meta();
    assert_eq!(meta.app_label, "webhosting");
    assert_eq!(meta.table_name, "webhosting_webdeployment");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on WebDeployment");
    assert_eq!(public_id_field.max_length, Some(36));

    let org_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on WebDeployment");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    let target_field = meta
        .fields
        .iter()
        .find(|f| f.name == "target")
        .expect("target field must exist on WebDeployment");
    assert_eq!(target_field.max_length, Some(32));

    let url_field = meta
        .fields
        .iter()
        .find(|f| f.name == "url")
        .expect("url field must exist on WebDeployment");
    assert_eq!(url_field.max_length, Some(500));

    let prefix_field = meta
        .fields
        .iter()
        .find(|f| f.name == "storage_prefix")
        .expect("storage_prefix field must exist on WebDeployment");
    assert_eq!(prefix_field.max_length, Some(500));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on WebDeployment");
    assert_eq!(status_field.max_length, Some(32));
    assert!(status_field.db_index, "status must be indexed");
}

#[test]
fn test_custom_domain_model_metadata() {
    let meta = CustomDomain::meta();
    assert_eq!(meta.app_label, "webhosting");
    assert_eq!(meta.table_name, "webhosting_customdomain");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on CustomDomain");
    assert_eq!(public_id_field.max_length, Some(36));

    let org_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on CustomDomain");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    let domain_field = meta
        .fields
        .iter()
        .find(|f| f.name == "domain")
        .expect("domain field must exist on CustomDomain");
    assert_eq!(domain_field.max_length, Some(255));

    let cert_status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "certificate_status")
        .expect("certificate_status field must exist on CustomDomain");
    assert_eq!(cert_status_field.max_length, Some(32));
}
