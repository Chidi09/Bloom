//! Route definitions and endpoint registration for the `events` app.

use djangors_core::Router;

use super::views;

/// Build the events router.
pub fn urls() -> Router {
    Router::new()
        .get("/events", views::list_events)
        // Registered before `/events/{id}` so the literal segment is not captured as an id.
        .sse("/events/stream", views::stream_events)
        .get("/events/{id}", views::retrieve_event)
}
