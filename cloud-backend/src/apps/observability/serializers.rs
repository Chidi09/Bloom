//! Serialization and transformation adapters for the `observability` domain app.

use super::contracts::{PlatformHealth, ReleaseHealthResponse};
use super::models::ReleaseHealthSnapshot;

/// Safely computes crash-free rate from sessions and crashes counts.
///
/// Returns `None` if `sessions` is `None`, 0, or negative, preventing division by zero or NaN.
pub fn compute_crash_free_rate(sessions: Option<i64>, crashes: Option<i64>) -> Option<f64> {
    match (sessions, crashes) {
        (Some(s), Some(c)) if s > 0 && c >= 0 => {
            let safe_crashes = c.min(s);
            let rate = (s - safe_crashes) as f64 / s as f64;
            Some((rate * 10000.0).round() / 10000.0)
        }
        _ => None,
    }
}

/// Derives a health status label from a crash-free rate.
pub fn derive_health_status(crash_free_rate: Option<f64>) -> String {
    match crash_free_rate {
        Some(rate) if rate >= 0.99 => "healthy".to_string(),
        Some(rate) if rate >= 0.95 => "warning".to_string(),
        Some(_) => "degraded".to_string(),
        None => "unknown".to_string(),
    }
}

/// Serializes a list of [`ReleaseHealthSnapshot`] rows into a [`ReleaseHealthResponse`].
///
/// Gracefully handles empty snapshot lists and safely parses stored JSON metadata without panicking.
pub fn serialize_release_health(
    release_public_id: &str,
    snapshots: &[ReleaseHealthSnapshot],
) -> ReleaseHealthResponse {
    if snapshots.is_empty() {
        return ReleaseHealthResponse {
            release_id: release_public_id.to_string(),
            overall_crash_free_rate: None,
            platforms: Vec::new(),
        };
    }

    let mut platforms = Vec::with_capacity(snapshots.len());
    let mut total_sessions: i64 = 0;
    let mut total_crashes: i64 = 0;
    let mut has_session_data = false;

    for snapshot in snapshots {
        let crash_free_rate = snapshot
            .crash_free_rate
            .or_else(|| compute_crash_free_rate(snapshot.sessions, snapshot.crashes));

        if let (Some(s), Some(c)) = (snapshot.sessions, snapshot.crashes) {
            if s > 0 {
                total_sessions += s;
                total_crashes += c.min(s);
                has_session_data = true;
            }
        }

        let status = derive_health_status(crash_free_rate);

        platforms.push(PlatformHealth {
            platform: snapshot.platform.clone(),
            target: snapshot.target.clone(),
            crash_free_rate,
            sessions: snapshot.sessions,
            crashes: snapshot.crashes,
            status,
        });
    }

    let overall_crash_free_rate = if has_session_data && total_sessions > 0 {
        compute_crash_free_rate(Some(total_sessions), Some(total_crashes))
    } else {
        let valid_rates: Vec<f64> = platforms
            .iter()
            .filter_map(|p| p.crash_free_rate)
            .filter(|r| r.is_finite() && !r.is_nan())
            .collect();
        if !valid_rates.is_empty() {
            let avg = valid_rates.iter().sum::<f64>() / valid_rates.len() as f64;
            Some((avg * 10000.0).round() / 10000.0)
        } else {
            None
        }
    };

    ReleaseHealthResponse {
        release_id: release_public_id.to_string(),
        overall_crash_free_rate,
        platforms,
    }
}

/// Parses the stored raw JSON metric string safely, defaulting to `{}` if unparseable.
pub fn parse_metric_data(raw: &str) -> serde_json::Value {
    serde_json::from_str(raw).unwrap_or_else(|_| serde_json::json!({}))
}
