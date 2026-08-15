use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};

/// Liveness probe: returns 200 OK as long as the process is alive.
pub async fn healthz(_req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    Ok(Response::text(StatusCode::OK, "ok"))
}

/// Readiness probe: returns 200 OK when backing services (database, Redis) are reachable,
/// or 503 Service Unavailable if any required dependency fails.
pub async fn readyz(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    // 1. Check database connectivity
    if let Some(db) = req.state::<djangors_db::Database>() {
        if let Err(e) = db.conn().execute("SELECT 1", &[]).await {
            return Ok(Response::text(
                StatusCode::SERVICE_UNAVAILABLE,
                &format!("database unavailable: {e}"),
            ));
        }
    } else {
        return Ok(Response::text(
            StatusCode::SERVICE_UNAVAILABLE,
            "database state not attached",
        ));
    }

    // 2. Check Redis connectivity via the job queue's PING.
    if let Some(queue) = req.state::<crate::infra::queue::JobQueue>() {
        if let Err(e) = queue.ping().await {
            return Ok(Response::text(
                StatusCode::SERVICE_UNAVAILABLE,
                &format!("redis unavailable: {e}"),
            ));
        }
    } else {
        // Fail closed: readiness must not report ready when a required dependency
        // was never wired up.
        return Ok(Response::text(
            StatusCode::SERVICE_UNAVAILABLE,
            "redis state not attached",
        ));
    }

    Ok(Response::text(StatusCode::OK, "ready"))
}
