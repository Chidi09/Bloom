//! Route definitions and endpoint registration for the `events` app.

use djangors_core::Router;

use super::views;

/// Build the events router.
pub fn urls() -> Router {
    Router::new()
        .get("/events", views::list_events)
        .get("/events/{id}", views::retrieve_event)
}
