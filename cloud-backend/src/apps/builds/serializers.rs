//! Serialization adapters and representation converters for `builds`.

use super::contracts::{BuildResponse, BuildStageResponse};
use super::models::{Build, BuildStage};

/// Serializes a [`BuildStage`] model instance into a [`BuildStageResponse`].
pub fn serialize_stage(stage: &BuildStage) -> BuildStageResponse {
    BuildStageResponse {
        stage: stage.stage.clone(),
        status: stage.status.clone(),
        started_at: stage.started_at.map(|dt| dt.to_rfc3339()),
        finished_at: stage.finished_at.map(|dt| dt.to_rfc3339()),
        log_snippet: stage.log_snippet.clone(),
    }
}

/// Serializes a [`Build`] model instance (with its stages) into a [`BuildResponse`].
///
/// `app_public_id`, `environment_public_id`, and `organization_public_id` are the
/// external UUID strings corresponding to the foreign keys on the model.
pub fn serialize_build(
    build: &Build,
    stages: &[BuildStage],
    app_public_id: &str,
    environment_public_id: &str,
    organization_public_id: &str,
) -> BuildResponse {
    BuildResponse {
        id: build.public_id.clone(),
        app_id: app_public_id.to_string(),
        environment_id: environment_public_id.to_string(),
        organization_id: organization_public_id.to_string(),
        git_commit: build.git_commit.clone(),
        git_branch: build.git_branch.clone(),
        git_ref: build.git_ref.clone(),
        status: build.status.clone(),
        platform: build.platform.clone(),
        build_profile: build.build_profile.clone(),
        flutter_version: build.flutter_version.clone(),
        dart_version: build.dart_version.clone(),
        bloom_version: build.bloom_version.clone(),
        flavor: build.flavor.clone(),
        started_at: build.started_at.map(|dt| dt.to_rfc3339()),
        finished_at: build.finished_at.map(|dt| dt.to_rfc3339()),
        logs_url: build.logs_url.clone(),
        stages: stages.iter().map(serialize_stage).collect(),
        created_at: build.created_at.to_rfc3339(),
        updated_at: build.updated_at.to_rfc3339(),
    }
}
