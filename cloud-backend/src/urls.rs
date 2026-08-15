use djangors_core::Router;

use crate::{apps, views};

/// Root router for the Bloom Cloud backend.
///
/// Mounts health endpoints (`/healthz`, `/readyz`) and domain application routes
/// under the `/api/v1` prefix.
pub fn root() -> Router {
    Router::new()
        .get("/healthz", views::healthz)
        .get("/readyz", views::readyz)
        .mount("/api/v1", apps::urls())
}
