//! Serialization and DTO mapping for `marketplace`.

use super::contracts::{
    InstallResponse, PurchaseResponse, RefundResponse, ReviewReportResponse, ReviewResponse,
    SellerAccountResponse, TemplateAccessResponse, TemplateDetailResponse, TemplateResponse,
    TemplateVersionResponse, TemplateVersionSummaryResponse,
};
use super::models::{
    ReviewReport, SellerAccount, Template, TemplatePurchase, TemplateReview, TemplateVersion,
};

/// Parse a JSON-in-TEXT string safely back to a [`serde_json::Value`].
///
/// Falls back to an empty JSON object `{}` on unparseable or empty input without panicking.
pub fn parse_json_safely(raw: &str) -> serde_json::Value {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return serde_json::json!({});
    }
    serde_json::from_str(trimmed).unwrap_or_else(|_| serde_json::json!({}))
}

/// Serialize a [`Template`] into a public wire [`TemplateResponse`].
pub fn serialize_template(
    template: &Template,
    organization_public_id: &str,
    latest_version: Option<String>,
    versions_count: i64,
) -> TemplateResponse {
    let is_featured = template.featured_type != "none";
    let is_editorial_featured = template.featured_type == "editorial";
    let is_paid_featured = template.featured_type == "paid";

    TemplateResponse {
        id: template.public_id.clone(),
        organization_id: organization_public_id.to_string(),
        name: template.name.clone(),
        slug: template.slug.clone(),
        description: template.description.clone(),
        visibility: template.visibility.clone(),
        status: template.status.clone(),
        is_free: template.is_free,
        price_amount: template.price_amount,
        price_currency: template.price_currency.clone(),
        metadata: parse_json_safely(&template.metadata),
        latest_version,
        versions_count,
        rating_count: template.rating_count,
        rating_bayesian_milli: template.rating_bayesian_milli,
        install_count: template.install_count,
        featured_type: template.featured_type.clone(),
        is_featured,
        is_editorial_featured,
        is_paid_featured,
        featured_until: template.featured_until.map(|t| t.to_rfc3339()),
        created_at: template.created_at.to_rfc3339(),
        updated_at: template.updated_at.to_rfc3339(),
    }
}

/// Serialize a [`Template`] with its version summaries into [`TemplateDetailResponse`].
pub fn serialize_template_detail(
    template: &Template,
    organization_public_id: &str,
    versions: &[TemplateVersion],
) -> TemplateDetailResponse {
    let version_summaries = versions.iter().map(serialize_version_summary).collect();
    let is_featured = template.featured_type != "none";
    let is_editorial_featured = template.featured_type == "editorial";
    let is_paid_featured = template.featured_type == "paid";

    TemplateDetailResponse {
        id: template.public_id.clone(),
        organization_id: organization_public_id.to_string(),
        name: template.name.clone(),
        slug: template.slug.clone(),
        description: template.description.clone(),
        visibility: template.visibility.clone(),
        status: template.status.clone(),
        is_free: template.is_free,
        price_amount: template.price_amount,
        price_currency: template.price_currency.clone(),
        metadata: parse_json_safely(&template.metadata),
        versions: version_summaries,
        rating_count: template.rating_count,
        rating_bayesian_milli: template.rating_bayesian_milli,
        install_count: template.install_count,
        featured_type: template.featured_type.clone(),
        is_featured,
        is_editorial_featured,
        is_paid_featured,
        featured_until: template.featured_until.map(|t| t.to_rfc3339()),
        created_at: template.created_at.to_rfc3339(),
        updated_at: template.updated_at.to_rfc3339(),
    }
}

/// Serialize a [`TemplateVersion`] into a public wire [`TemplateVersionResponse`].
pub fn serialize_template_version(
    version: &TemplateVersion,
    template_public_id: &str,
) -> TemplateVersionResponse {
    TemplateVersionResponse {
        id: version.public_id.clone(),
        template_id: template_public_id.to_string(),
        version: version.version.clone(),
        changelog: version.changelog.clone(),
        manifest: parse_json_safely(&version.manifest),
        readme: version.readme.clone(),
        install_count: version.install_count,
        created_at: version.created_at.to_rfc3339(),
        updated_at: version.updated_at.to_rfc3339(),
    }
}

/// Serialize a [`TemplateVersion`] into a lightweight summary [`TemplateVersionSummaryResponse`].
pub fn serialize_version_summary(version: &TemplateVersion) -> TemplateVersionSummaryResponse {
    TemplateVersionSummaryResponse {
        id: version.public_id.clone(),
        version: version.version.clone(),
        changelog: version.changelog.clone(),
        install_count: version.install_count,
        created_at: version.created_at.to_rfc3339(),
    }
}

/// Serialize a [`SellerAccount`] into [`SellerAccountResponse`].
pub fn serialize_seller_account(
    account: &SellerAccount,
    organization_public_id: &str,
) -> SellerAccountResponse {
    SellerAccountResponse {
        id: account.public_id.clone(),
        organization_id: organization_public_id.to_string(),
        stripe_account_id: account.stripe_account_id.clone(),
        payouts_enabled: account.payouts_enabled,
        charges_enabled: account.charges_enabled,
        details_submitted: account.details_submitted,
        default_currency: account.default_currency.clone(),
        last_payouts_checked_at: account.last_payouts_checked_at.map(|t| t.to_rfc3339()),
        created_at: account.created_at.to_rfc3339(),
        updated_at: account.updated_at.to_rfc3339(),
    }
}

/// Serialize a [`TemplatePurchase`] into [`PurchaseResponse`].
pub fn serialize_purchase(
    purchase: &TemplatePurchase,
    buyer_org_public_id: &str,
    template_public_id: &str,
    template_name: &str,
    version_public_id: Option<String>,
    seller_org_public_id: &str,
    client_secret: Option<String>,
) -> PurchaseResponse {
    PurchaseResponse {
        id: purchase.public_id.clone(),
        buyer_organization_id: buyer_org_public_id.to_string(),
        template_id: template_public_id.to_string(),
        template_name: template_name.to_string(),
        template_version_id: version_public_id,
        seller_organization_id: seller_org_public_id.to_string(),
        amount: purchase.amount,
        currency: purchase.currency.clone(),
        platform_fee: purchase.platform_fee,
        seller_amount: purchase.seller_amount,
        status: purchase.status.clone(),
        client_secret,
        created_at: purchase.created_at.to_rfc3339(),
    }
}

/// Serialize a refund outcome into [`RefundResponse`].
pub fn serialize_refund(
    purchase_public_id: &str,
    stripe_refund_id: &str,
    amount: i64,
    currency: &str,
    status: &str,
) -> RefundResponse {
    RefundResponse {
        purchase_id: purchase_public_id.to_string(),
        stripe_refund_id: stripe_refund_id.to_string(),
        amount,
        currency: currency.to_string(),
        status: status.to_string(),
    }
}

/// Serialize access check outcome into [`TemplateAccessResponse`].
pub fn serialize_access(
    has_access: bool,
    reason: &str,
    template_public_id: &str,
    version_public_id: Option<String>,
) -> TemplateAccessResponse {
    TemplateAccessResponse {
        has_access,
        access_reason: reason.to_string(),
        template_id: template_public_id.to_string(),
        version_id: version_public_id,
    }
}

/// Serialize a [`TemplateReview`] into public wire [`ReviewResponse`].
pub fn serialize_review(
    review: &TemplateReview,
    template_public_id: &str,
    buyer_org_public_id: &str,
) -> ReviewResponse {
    ReviewResponse {
        id: review.public_id.clone(),
        template_id: template_public_id.to_string(),
        buyer_organization_id: buyer_org_public_id.to_string(),
        rating: review.rating,
        title: review.title.clone(),
        comment: review.comment.clone(),
        status: review.status.clone(),
        author_response: review.author_response.clone(),
        author_responded_at: review.author_responded_at.map(|t| t.to_rfc3339()),
        created_at: review.created_at.to_rfc3339(),
        updated_at: review.updated_at.to_rfc3339(),
    }
}

/// Serialize a [`ReviewReport`] into [`ReviewReportResponse`].
pub fn serialize_review_report(
    report: &ReviewReport,
    review_public_id: &str,
    reporter_org_public_id: &str,
) -> ReviewReportResponse {
    ReviewReportResponse {
        id: report.public_id.clone(),
        review_id: review_public_id.to_string(),
        reporter_organization_id: reporter_org_public_id.to_string(),
        reason: report.reason.clone(),
        details: report.details.clone(),
        status: report.status.clone(),
        created_at: report.created_at.to_rfc3339(),
    }
}

/// Serialize an install recording outcome into [`InstallResponse`].
pub fn serialize_install(
    template_public_id: &str,
    version_public_id: Option<String>,
    install_count: i64,
    deduplicated: bool,
) -> InstallResponse {
    InstallResponse {
        template_id: template_public_id.to_string(),
        template_version_id: version_public_id,
        install_count,
        deduplicated,
    }
}
