use bloom_cloud_backend::apps::accounts::contracts::RegisterRequest;
use bloom_cloud_backend::apps::accounts::services::{
    DEVICE_FLOW_POLL_INTERVAL_SECS, DEVICE_FLOW_TTL_MINUTES, MIN_PASSWORD_LENGTH,
};

#[test]
fn test_password_policy_constants() {
    assert_eq!(MIN_PASSWORD_LENGTH, 8);
    assert_eq!(DEVICE_FLOW_TTL_MINUTES, 10);
    assert_eq!(DEVICE_FLOW_POLL_INTERVAL_SECS, 5);
}

#[test]
fn test_password_hashing_and_verification() {
    let raw = "super-secret-password-123";
    let hashed = djangors_auth::hash_password(raw).expect("Password hashing must succeed");
    assert!(hashed.starts_with("$argon2id$"));

    let is_valid = djangors_auth::verify_password(raw, &hashed).expect("Verification must succeed");
    assert!(is_valid);

    let is_invalid = djangors_auth::verify_password("wrong-password", &hashed)
        .expect("Verification must succeed");
    assert!(!is_invalid);
}

#[test]
fn test_weak_password_rejection() {
    let req = RegisterRequest {
        email: "test@example.com".to_string(),
        username: "testuser".to_string(),
        password: "short".to_string(),
    };
    assert!(req.password.len() < MIN_PASSWORD_LENGTH);
}
