//! Role-based permissions, organization context, and resolution middleware.

use djangors_core::request::Request;
use djangors_db::Database;
use serde::{Deserialize, Serialize};
use std::str::FromStr;
use std::sync::Arc;
use tower::{Layer, Service};

use super::errors::OrganizationError;
use super::repositories;
use crate::apps::common::scoping::OrganizationResolutionFailed;

/// Standardized roles within an organization, ordered by hierarchy level.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OrganizationRole {
    /// Read-only access to organization resources.
    Viewer = 1,
    /// Can build, test, and deploy to non-production environments.
    Developer = 2,
    /// Can manage signing, secrets, and approve production deployments.
    ReleaseManager = 3,
    /// Can manage projects, apps, and members (excluding owners and billing).
    Admin = 4,
    /// Full administrative and billing control.
    Owner = 5,
}

impl std::str::FromStr for OrganizationRole {
    type Err = OrganizationError;

    /// Parse a role string into an [`OrganizationRole`] variant.
    fn from_str(s: &str) -> Result<Self, OrganizationError> {
        match s.to_lowercase().as_str() {
            "viewer" => Ok(Self::Viewer),
            "developer" => Ok(Self::Developer),
            "release_manager" => Ok(Self::ReleaseManager),
            "admin" => Ok(Self::Admin),
            "owner" => Ok(Self::Owner),
            _ => Err(OrganizationError::InvalidRole),
        }
    }
}

impl OrganizationRole {
    /// Return the canonical string identifier for this role.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Viewer => "viewer",
            Self::Developer => "developer",
            Self::ReleaseManager => "release_manager",
            Self::Admin => "admin",
            Self::Owner => "owner",
        }
    }
}

/// Request extension holding the authenticated user's role in the active organization.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CurrentOrganizationRole(pub String);

/// Request extension holding the active organization's public UUID identifier.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CurrentOrganizationPublicId(pub String);

/// Requires the caller to have at least `min_role` membership in the active organization.
#[derive(Debug, Clone)]
pub struct OrganizationPermission {
    pub min_role: OrganizationRole,
}

impl OrganizationPermission {
    /// Permission requiring at least `Viewer` role.
    pub fn viewer() -> Self {
        Self {
            min_role: OrganizationRole::Viewer,
        }
    }

    /// Permission requiring at least `Developer` role.
    pub fn developer() -> Self {
        Self {
            min_role: OrganizationRole::Developer,
        }
    }

    /// Permission requiring at least `ReleaseManager` role.
    pub fn release_manager() -> Self {
        Self {
            min_role: OrganizationRole::ReleaseManager,
        }
    }

    /// Permission requiring at least `Admin` role.
    pub fn admin() -> Self {
        Self {
            min_role: OrganizationRole::Admin,
        }
    }

    /// Permission requiring `Owner` role.
    pub fn owner() -> Self {
        Self {
            min_role: OrganizationRole::Owner,
        }
    }
}

#[async_trait::async_trait]
impl djangors_rest::Permission for OrganizationPermission {
    async fn has_permission(&self, req: &Request) -> bool {
        // 1. Request must be authenticated
        let user = match djangors_rest::current_user(req).await {
            Some(u) => u,
            None => return false,
        };

        if user.is_superuser {
            return true;
        }

        // 2. CurrentOrganizationId must exist in extensions
        let org_id = match req.ext::<crate::apps::accounts::CurrentOrganizationId>() {
            Some(id) => id.0,
            None => return false,
        };

        // 3. User's role must meet or exceed min_role
        if let Some(role_ext) = req.ext::<CurrentOrganizationRole>() {
            if let Ok(role) = OrganizationRole::from_str(&role_ext.0) {
                return role >= self.min_role;
            }
        }

        // If not in extensions, query database if available
        if let Some(db) = req.state::<Database>() {
            if let Ok(Some(membership)) =
                repositories::membership_for_user_in_org(db, user.id, org_id).await
            {
                if let Ok(role) = OrganizationRole::from_str(&membership.role) {
                    return role >= self.min_role;
                }
            }
        }

        false
    }
}

// =========================================================================
// Organization Resolution Middleware
// =========================================================================

/// Tower layer that resolves the active organization from `X-Bloom-Organization-Id`
/// header and current authenticated user, inserting [`crate::apps::accounts::CurrentOrganizationId`],
/// [`CurrentOrganizationRole`], and [`CurrentOrganizationPublicId`] into request extensions.
#[derive(Clone)]
pub struct OrganizationResolutionLayer<F> {
    db: Arc<Database>,
    user_id_extractor: F,
}

impl<F> OrganizationResolutionLayer<F> {
    /// Create a new layer with a custom user ID extractor closure.
    pub fn new(db: Database, user_id_extractor: F) -> Self {
        Self {
            db: Arc::new(db),
            user_id_extractor,
        }
    }
}

impl<S, F> Layer<S> for OrganizationResolutionLayer<F>
where
    F: Clone,
{
    type Service = OrganizationResolutionService<S, F>;

    fn layer(&self, inner: S) -> Self::Service {
        OrganizationResolutionService {
            inner,
            db: self.db.clone(),
            user_id_extractor: self.user_id_extractor.clone(),
        }
    }
}

/// Tower service produced by [`OrganizationResolutionLayer`].
#[derive(Clone)]
pub struct OrganizationResolutionService<S, F> {
    inner: S,
    db: Arc<Database>,
    user_id_extractor: F,
}

impl<S, F, ReqBody, ResBody> Service<hyper::Request<ReqBody>>
    for OrganizationResolutionService<S, F>
where
    S: Service<hyper::Request<ReqBody>, Response = hyper::Response<ResBody>>
        + Clone
        + Send
        + 'static,
    S::Future: Send + 'static,
    F: Fn(&hyper::Request<ReqBody>) -> Option<i64> + Clone + Send + 'static,
    ReqBody: Send + 'static,
    ResBody: Send + 'static,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = std::pin::Pin<
        Box<dyn std::future::Future<Output = Result<Self::Response, Self::Error>> + Send>,
    >;

    fn poll_ready(
        &mut self,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, mut req: hyper::Request<ReqBody>) -> Self::Future {
        let mut inner = self.inner.clone();
        let db = self.db.clone();

        let org_header = req
            .headers()
            .get("x-bloom-organization-id")
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string());

        let user_id = (self.user_id_extractor)(&req);

        Box::pin(async move {
            if let (Some(org_public_id), Some(uid)) = (org_header, user_id) {
                match repositories::organization_by_public_id(&db, &org_public_id).await {
                    Ok(Some(org)) => {
                        match repositories::membership_for_user_in_org(&db, uid, org.id).await {
                            Ok(Some(membership)) => {
                                req.extensions_mut()
                                    .insert(crate::apps::accounts::CurrentOrganizationId(org.id));
                                req.extensions_mut()
                                    .insert(CurrentOrganizationRole(membership.role));
                                req.extensions_mut()
                                    .insert(CurrentOrganizationPublicId(org.public_id));
                            }
                            Ok(None) => {
                                // Not a member of this organization; leave extensions empty
                            }
                            Err(_e) => {
                                req.extensions_mut().insert(OrganizationResolutionFailed);
                            }
                        }
                    }
                    Ok(None) => {
                        // Organization with this public_id does not exist; leave extensions empty
                    }
                    Err(_e) => {
                        req.extensions_mut().insert(OrganizationResolutionFailed);
                    }
                }
            }
            inner.call(req).await
        })
    }
}
