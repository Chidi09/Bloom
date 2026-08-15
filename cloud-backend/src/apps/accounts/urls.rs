//! Route registration for the `accounts` app.

use djangors_core::Router;

use super::views;

/// Build the accounts router containing all authentication and token endpoints.
pub fn urls() -> Router {
    Router::new()
        .post("/auth/register", views::register)
        .post("/auth/login", views::login)
        .post("/auth/device", views::device_flow_init)
        .get("/auth/device/token", views::device_flow_poll)
        .post("/auth/device/authorize", views::device_flow_authorize)
        .post("/auth/token", views::create_api_token)
        .delete("/auth/token/{id}", views::revoke_api_token)
        .post("/auth/refresh", views::refresh_token)
        .get("/auth/me", views::me)
        .post("/auth/logout", views::logout)
}
