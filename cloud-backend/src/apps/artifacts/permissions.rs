//! Role-based permissions, worker job-token authentication, and authorization helpers for `artifacts`.

use djangors_core::Request;

pub use crate::apps::accounts::permissions::CurrentOrganizationId;
pub use crate::apps::organizations::permissions::{
    CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};

use super::errors::ArtifactError;

/// Enforce that the caller is an internal worker presenting a valid job token.
///
/// TODO(spec): the authoritative job-token issuance/verification is defined by the
/// worker queue infrastructure (`src/infra/queue.rs`) in Phase 3. Until then the token
/// is compared in constant time against `BLOOM_WORKER_JOB_TOKEN`; requests without a
/// configured token are refused (fail closed).
pub fn require_job_token(req: &Request) -> Result<(), ArtifactError> {
    let presented = req
        .header("x-bloom-job-token")
        .and_then(|v| v.to_str().ok());

    let expected = std::env::var("BLOOM_WORKER_JOB_TOKEN").ok();

    match (presented, expected) {
        (Some(token), Some(expected))
            if crate::infra::crypto::Crypto::constant_time_eq_str(token, &expected) =>
        {
            Ok(())
        }
        _ => Err(ArtifactError::InvalidJobToken),
    }
}
