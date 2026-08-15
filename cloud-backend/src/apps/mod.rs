pub mod accounts;
// The `apps` domain app lives under the `apps` module tree like every other domain app;
// the name collision is inherent to the layout, not an accident.
#[allow(clippy::module_inception)]
pub mod apps;
pub mod artifacts;
pub mod billing;
pub mod builds;
pub mod common;
pub mod credentials;
pub mod deployments;
pub mod environments;
pub mod events;
pub mod git_connections;
pub mod marketplace;
pub mod observability;
pub mod organizations;
pub mod projects;
pub mod releases;
pub mod secrets;
pub mod signing;
pub mod webhosting;
pub mod workflows;

use djangors_core::Router;

/// Domain application route composition point.
///
/// Mounts all domain-level applications (e.g. accounts, organizations, projects)
/// under the `/api/v1` namespace.
pub fn urls() -> Router {
    Router::new()
        .mount("", accounts::urls())
        .mount("", organizations::urls())
        .mount("", environments::urls())
        .mount("", apps::urls())
        .mount("", projects::urls())
        .mount("", credentials::urls())
        .mount("", secrets::urls())
        .mount("", signing::urls())
        // Phase 3: events is the write sink every other app emits through; builds owns the
        // queueing path and artifacts the storage path.
        .mount("", events::urls())
        .mount("", builds::urls())
        .mount("", artifacts::urls())
        // Phase 4: releases group artifacts; webhosting deploys the web bundle.
        .mount("", releases::urls())
        .mount("", webhosting::urls())
        // Phase 5: mobile store deployments and the metrics they report back.
        .mount("", deployments::urls())
        .mount("", observability::urls())
        // Phase 6: git connections drive workflow runs, so both mount together.
        .mount("", git_connections::urls())
        .mount("", workflows::urls())
        // Phases 7-8: metered billing, and the templates/marketplace foundation.
        .mount("", billing::urls())
        .mount("", marketplace::urls())
}
