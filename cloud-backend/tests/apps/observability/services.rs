use chrono::Utc;
use djangors_orm::ForeignKey;
use serde_json::json;

use bloom_cloud_backend::apps::observability::models::ReleaseHealthSnapshot;
use bloom_cloud_backend::apps::observability::serializers::{
    compute_crash_free_rate, derive_health_status, parse_metric_data, serialize_release_health,
};
use bloom_cloud_backend::apps::observability::services::{
    capture_health_snapshot, get_app_status, get_release_health, record_platform_metric,
    HealthSnapshotInput,
};

#[test]
fn test_zero_denominator_crash_free_rate_handling() {
    // 0 sessions must return None, preventing division-by-zero, NaN, or panic
    assert_eq!(compute_crash_free_rate(Some(0), Some(0)), None);
    assert_eq!(compute_crash_free_rate(Some(0), Some(5)), None);

    // Negative sessions must return None
    assert_eq!(compute_crash_free_rate(Some(-10), Some(2)), None);

    // Missing sessions or crashes must return None
    assert_eq!(compute_crash_free_rate(None, Some(5)), None);
    assert_eq!(compute_crash_free_rate(Some(100), None), None);
    assert_eq!(compute_crash_free_rate(None, None), None);

    // Valid sessions with 0 crashes = 1.0 (100% crash free)
    assert_eq!(compute_crash_free_rate(Some(1000), Some(0)), Some(1.0));

    // Valid sessions with crashes = (sessions - crashes) / sessions
    assert_eq!(compute_crash_free_rate(Some(1000), Some(2)), Some(0.998));
    assert_eq!(compute_crash_free_rate(Some(100), Some(10)), Some(0.9));

    // Crashes exceeding sessions are clamped to 0.0 crash-free, not negative
    assert_eq!(compute_crash_free_rate(Some(50), Some(100)), Some(0.0));
}

#[test]
fn test_derive_health_status() {
    assert_eq!(derive_health_status(Some(0.995)), "healthy");
    assert_eq!(derive_health_status(Some(0.990)), "healthy");
    assert_eq!(derive_health_status(Some(0.980)), "warning");
    assert_eq!(derive_health_status(Some(0.950)), "warning");
    assert_eq!(derive_health_status(Some(0.920)), "degraded");
    assert_eq!(derive_health_status(Some(0.0)), "degraded");
    assert_eq!(derive_health_status(None), "unknown");
}

#[test]
fn test_serialize_release_health_absent_data() {
    let response = serialize_release_health("rel-001", &[]);
    assert_eq!(response.release_id, "rel-001");
    assert_eq!(response.overall_crash_free_rate, None);
    assert!(response.platforms.is_empty());
}

#[test]
fn test_serialize_release_health_multi_platform_aggregation() {
    let snapshots = vec![
        ReleaseHealthSnapshot {
            id: 1,
            release_id: ForeignKey::new(10),
            platform: "ios".to_string(),
            target: "testflight".to_string(),
            crash_free_rate: Some(0.99),
            sessions: Some(1000),
            crashes: Some(10),
            active_users: Some(500),
            metric_data: json!({ "app_store_version": "1.0.0" }).to_string(),
            captured_at: Utc::now(),
        },
        ReleaseHealthSnapshot {
            id: 2,
            release_id: ForeignKey::new(10),
            platform: "android".to_string(),
            target: "google_play".to_string(),
            crash_free_rate: Some(0.98),
            sessions: Some(1000),
            crashes: Some(20),
            active_users: Some(600),
            metric_data: json!({ "track": "internal" }).to_string(),
            captured_at: Utc::now(),
        },
    ];

    let response = serialize_release_health("rel-10", &snapshots);
    assert_eq!(response.release_id, "rel-10");
    assert_eq!(response.platforms.len(), 2);

    // Overall: (2000 - 30) / 2000 = 1970 / 2000 = 0.985
    assert_eq!(response.overall_crash_free_rate, Some(0.985));

    let ios = response
        .platforms
        .iter()
        .find(|p| p.platform == "ios")
        .unwrap();
    assert_eq!(ios.target, "testflight");
    assert_eq!(ios.sessions, Some(1000));
    assert_eq!(ios.crashes, Some(10));
    assert_eq!(ios.crash_free_rate, Some(0.99));
    assert_eq!(ios.status, "healthy");

    let android = response
        .platforms
        .iter()
        .find(|p| p.platform == "android")
        .unwrap();
    assert_eq!(android.target, "google_play");
    assert_eq!(android.sessions, Some(1000));
    assert_eq!(android.crashes, Some(20));
    assert_eq!(android.crash_free_rate, Some(0.98));
    assert_eq!(android.status, "warning");
}

#[test]
fn test_metric_data_json_safe_parsing() {
    let valid = parse_metric_data(r#"{"crashes_by_type":{"sigsegv":2}}"#);
    assert_eq!(valid["crashes_by_type"]["sigsegv"], 2);

    let invalid = parse_metric_data("not valid json");
    assert_eq!(invalid, serde_json::json!({}));
}

#[tokio::test]
async fn test_observability_db_operations_and_scoping() {
    let config = djangors_db::DatabaseConfig::new("sqlite::memory:").max_connections(1);
    let db = djangors_db::Database::connect(&config)
        .await
        .expect("sqlite in-memory database connects");

    // Create required tables in SQLite for testing
    db.conn()
        .execute(
            "CREATE TABLE apps_app (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                public_id VARCHAR(36) NOT NULL UNIQUE,
                project_id BIGINT NOT NULL,
                organization_id BIGINT NOT NULL,
                name VARCHAR(255) NOT NULL,
                slug VARCHAR(64) NOT NULL,
                repository_url VARCHAR(500),
                default_branch VARCHAR(255) NOT NULL DEFAULT 'main',
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE environments_environment (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                public_id VARCHAR(36) NOT NULL UNIQUE,
                app_id BIGINT NOT NULL,
                organization_id BIGINT NOT NULL,
                name VARCHAR(255) NOT NULL,
                slug VARCHAR(64) NOT NULL,
                api_config TEXT NOT NULL DEFAULT '{}',
                build_profile VARCHAR(32) NOT NULL DEFAULT 'release',
                flutter_version VARCHAR(64),
                dart_version VARCHAR(64),
                bloom_version VARCHAR(64),
                flavor VARCHAR(64),
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE releases_release (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                public_id VARCHAR(36) NOT NULL UNIQUE,
                app_id BIGINT NOT NULL,
                organization_id BIGINT NOT NULL,
                version VARCHAR(64) NOT NULL,
                build_number BIGINT NOT NULL,
                \"commit\" VARCHAR(40) NOT NULL DEFAULT '',
                changelog TEXT NOT NULL DEFAULT '',
                environment_id BIGINT,
                status VARCHAR(32) NOT NULL DEFAULT 'released',
                platforms TEXT NOT NULL DEFAULT '[]',
                artifacts TEXT NOT NULL DEFAULT '[]',
                rollout_status TEXT NOT NULL DEFAULT '{}',
                created_by_id BIGINT NOT NULL DEFAULT 1,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE observability_releasehealthsnapshot (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                release_id BIGINT NOT NULL,
                platform VARCHAR(32) NOT NULL,
                target VARCHAR(32) NOT NULL,
                crash_free_rate REAL,
                sessions BIGINT,
                crashes BIGINT,
                active_users BIGINT,
                metric_data TEXT NOT NULL DEFAULT '{}',
                captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE observability_platformmetric (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                deployment_id BIGINT NOT NULL,
                metric_type VARCHAR(32) NOT NULL,
                value BIGINT NOT NULL,
                captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );",
            &[],
        )
        .await
        .expect("create test tables");

    // Insert App and Release for org 100
    db.conn()
        .execute(
            "INSERT INTO apps_app (id, public_id, project_id, organization_id, name, slug)
             VALUES (1, 'app-pub-100', 1, 100, 'Test App', 'test-app');
             INSERT INTO environments_environment (id, public_id, app_id, organization_id, name, slug)
             VALUES (1, 'env-pub-prod', 1, 100, 'Production', 'production');
             INSERT INTO releases_release (id, public_id, app_id, organization_id, version, build_number, environment_id, status, platforms)
             VALUES (1, 'rel-pub-100', 1, 100, '1.0.0', 1, 1, 'released', '[\"ios\", \"android\"]');",
            &[],
        )
        .await
        .expect("seed org 100 data");

    // 1. Capture snapshot for release 1
    let snap = capture_health_snapshot(
        &db,
        1,
        "ios",
        "testflight",
        HealthSnapshotInput {
            crash_free_rate: None,
            sessions: Some(500),
            crashes: Some(1),
            active_users: Some(250),
            metric_data: json!({ "vendor": "apple" }),
        },
    )
    .await
    .expect("capture snapshot succeeds");
    assert_eq!(snap.platform, "ios");
    assert_eq!(snap.crash_free_rate, Some(0.998));

    // 2. Record platform metric for deployment 42
    let metric = record_platform_metric(&db, 42, "crash", 5)
        .await
        .expect("record platform metric succeeds");
    assert_eq!(metric.deployment_id.id, 42);
    assert_eq!(metric.metric_type, "crash");
    assert_eq!(metric.value, 5);

    // 3. Organization scoping test: Org 100 can retrieve release health
    let health = get_release_health(&db, "rel-pub-100", 100)
        .await
        .expect("org 100 can fetch release health");
    assert_eq!(health.release_id, "rel-pub-100");
    assert_eq!(health.platforms.len(), 1);
    assert_eq!(health.platforms[0].platform, "ios");
    assert_eq!(health.overall_crash_free_rate, Some(0.998));

    // Cross-tenant access: Org 200 cannot access Org 100's release
    let cross_org_res = get_release_health(&db, "rel-pub-100", 200).await;
    assert!(cross_org_res.is_err(), "cross-org release lookup must fail");

    // 4. App status test for Org 100
    let app_status = get_app_status(&db, "app-pub-100", 100)
        .await
        .expect("org 100 can fetch app status");
    assert_eq!(app_status.app_id, "app-pub-100");
    assert_eq!(app_status.environments.len(), 2); // ios and android for production env

    // Cross-tenant access: Org 200 cannot access Org 100's app status
    let cross_app_res = get_app_status(&db, "app-pub-100", 200).await;
    assert!(cross_app_res.is_err(), "cross-org app lookup must fail");

    // 5. Absent-data path: Create release with NO snapshots in Org 100
    db.conn()
        .execute(
            "INSERT INTO releases_release (id, public_id, app_id, organization_id, version, build_number, environment_id, status, platforms)
             VALUES (2, 'rel-pub-empty', 1, 100, '2.0.0', 2, NULL, 'draft', '[\"web\"]');",
            &[],
        )
        .await
        .expect("seed empty release");

    let empty_health = get_release_health(&db, "rel-pub-empty", 100)
        .await
        .expect("absent-data path returns 200 OK well-formed response");
    assert_eq!(empty_health.release_id, "rel-pub-empty");
    assert_eq!(empty_health.overall_crash_free_rate, None);
    assert!(empty_health.platforms.is_empty());
}
