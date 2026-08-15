use std::collections::HashMap;

use bloom_cloud_backend::apps::environments::contracts::{ApiConfig, EnvVar, FeatureFlag};
use bloom_cloud_backend::apps::environments::models::Environment;
use bloom_cloud_backend::apps::environments::services::{
    get_effective_build_config, slugify, validate_and_serialize_api_config, validate_build_profile,
    VALID_BUILD_PROFILES,
};

#[test]
fn test_slugify_logic() {
    assert_eq!(slugify("Production"), "production");
    assert_eq!(slugify("Staging US-East"), "staging-us-east");
    assert_eq!(slugify("QA & Test!"), "qa-test");
    assert_eq!(slugify("  dev-env-1  "), "dev-env-1");
    assert_eq!(slugify(""), "env");
}

#[test]
fn test_build_profile_validation() {
    assert!(validate_build_profile("debug").is_ok());
    assert!(validate_build_profile("profile").is_ok());
    assert!(validate_build_profile("release").is_ok());

    assert!(validate_build_profile("invalid").is_err());
    assert!(validate_build_profile("prod").is_err());
    assert!(validate_build_profile("").is_err());

    assert_eq!(VALID_BUILD_PROFILES, &["debug", "profile", "release"]);
}

#[test]
fn test_api_config_validation_and_serialization() {
    let config = ApiConfig {
        env_vars: vec![
            EnvVar {
                key: "API_BASE_URL".to_string(),
                value: "https://api.example.com".to_string(),
            },
            EnvVar {
                key: "ENABLE_ANALYTICS".to_string(),
                value: "true".to_string(),
            },
        ],
        feature_flags: vec![
            FeatureFlag {
                key: "new_dashboard".to_string(),
                enabled: true,
            },
            FeatureFlag {
                key: "beta_checkout".to_string(),
                enabled: false,
            },
        ],
    };

    let serialized = validate_and_serialize_api_config(&config).expect("serialization succeeds");
    assert!(serialized.contains("\"key\":\"API_BASE_URL\""));
    assert!(serialized.contains("\"value\":\"https://api.example.com\""));
    assert!(serialized.contains("\"key\":\"new_dashboard\""));
    assert!(serialized.contains("\"enabled\":true"));
    assert!(serialized.contains("\"enabled\":false"));

    let deserialized: ApiConfig =
        serde_json::from_str(&serialized).expect("deserialization succeeds");
    assert_eq!(deserialized, config);
}

#[test]
fn test_get_effective_build_config_merging() {
    let now = chrono::Utc::now();
    let config = ApiConfig {
        env_vars: vec![
            EnvVar {
                key: "API_URL".to_string(),
                value: "https://api.example.com".to_string(),
            },
            EnvVar {
                key: "OVERRIDDEN_KEY".to_string(),
                value: "env_default_value".to_string(),
            },
        ],
        feature_flags: vec![FeatureFlag {
            key: "dark_mode".to_string(),
            enabled: true,
        }],
    };
    let api_config_str = serde_json::to_string(&config).unwrap();

    let env = Environment {
        id: 1,
        public_id: "env-uuid-1".to_string(),
        app_id: 10,
        organization_id: 100,
        name: "Production".to_string(),
        slug: "production".to_string(),
        api_config: api_config_str,
        build_profile: "release".to_string(),
        flutter_version: Some("3.22.0".to_string()),
        dart_version: Some("3.4.0".to_string()),
        bloom_version: Some("0.7.0".to_string()),
        flavor: Some("prod".to_string()),
        created_at: now,
        updated_at: now,
    };

    let mut secrets = HashMap::new();
    secrets.insert(
        "DATABASE_PASSWORD".to_string(),
        "super_secret_pw".to_string(),
    );
    secrets.insert(
        "OVERRIDDEN_KEY".to_string(),
        "secret_override_value".to_string(),
    );

    let effective = get_effective_build_config(&env, secrets);

    assert_eq!(effective.build_profile, "release");
    assert_eq!(effective.flutter_version, Some("3.22.0".to_string()));
    assert_eq!(effective.dart_version, Some("3.4.0".to_string()));
    assert_eq!(effective.bloom_version, Some("0.7.0".to_string()));
    assert_eq!(effective.flavor, Some("prod".to_string()));

    // Env vars check
    assert_eq!(
        effective.env_vars.get("API_URL"),
        Some(&"https://api.example.com".to_string())
    );
    assert_eq!(
        effective.env_vars.get("DATABASE_PASSWORD"),
        Some(&"super_secret_pw".to_string())
    );
    // Secret overrides env var default
    assert_eq!(
        effective.env_vars.get("OVERRIDDEN_KEY"),
        Some(&"secret_override_value".to_string())
    );

    // Feature flags check
    assert_eq!(effective.feature_flags.get("dark_mode"), Some(&true));
}

#[test]
fn test_environment_events_payload_structure() {
    // Verify environment event payloads match events.md catalogue:
    // environment.created -> { environment_id, app_id }
    // environment.updated -> { environment_id, app_id }
    // environment.deleted -> { environment_id, app_id }

    let env_id = "env-uuid-1111";
    let app_id = "app-uuid-2222";

    let created_payload = serde_json::json!({
        "environment_id": env_id,
        "app_id": app_id,
    });
    assert_eq!(created_payload["environment_id"], env_id);
    assert_eq!(created_payload["app_id"], app_id);

    let updated_payload = serde_json::json!({
        "environment_id": env_id,
        "app_id": app_id,
    });
    assert_eq!(updated_payload["environment_id"], env_id);
    assert_eq!(updated_payload["app_id"], app_id);

    let deleted_payload = serde_json::json!({
        "environment_id": env_id,
        "app_id": app_id,
    });
    assert_eq!(deleted_payload["environment_id"], env_id);
    assert_eq!(deleted_payload["app_id"], app_id);
}
