use bloom_cloud_backend::apps::accounts::models::{ApiToken, DeviceFlowRequest, UserProfile};

#[test]
fn test_accounts_models_metadata() {
    let profile_meta = UserProfile::meta();
    assert_eq!(profile_meta.app_label, "accounts");
    assert_eq!(profile_meta.table_name, "accounts_userprofile");

    let user_id_field = profile_meta
        .fields
        .iter()
        .find(|f| f.name == "user_id")
        .expect("user_id field must exist on UserProfile");
    assert!(
        user_id_field.unique,
        "user_id must be unique on UserProfile"
    );

    let public_id_field = profile_meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on UserProfile");
    assert_eq!(public_id_field.max_length, Some(36));

    let token_meta = ApiToken::meta();
    assert_eq!(token_meta.app_label, "accounts");
    assert_eq!(token_meta.table_name, "accounts_apitoken");

    let token_hash_field = token_meta
        .fields
        .iter()
        .find(|f| f.name == "token_hash")
        .expect("token_hash field must exist on ApiToken");
    assert!(
        token_hash_field.unique,
        "token_hash must be unique on ApiToken"
    );
    assert_eq!(token_hash_field.max_length, Some(64));

    let device_meta = DeviceFlowRequest::meta();
    assert_eq!(device_meta.app_label, "accounts");
    assert_eq!(device_meta.table_name, "accounts_deviceflowrequest");

    let device_code_field = device_meta
        .fields
        .iter()
        .find(|f| f.name == "device_code")
        .expect("device_code field must exist on DeviceFlowRequest");
    assert!(device_code_field.unique, "device_code must be unique");
    assert_eq!(device_code_field.max_length, Some(80));

    let user_code_field = device_meta
        .fields
        .iter()
        .find(|f| f.name == "user_code")
        .expect("user_code field must exist on DeviceFlowRequest");
    assert!(user_code_field.db_index, "user_code must be indexed");
    assert_eq!(user_code_field.max_length, Some(16));
}
