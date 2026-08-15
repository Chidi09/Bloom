//! Renders every Bloom email template and the receipt document with fixture data.
//!
//! This exists so the templates are validated by the engine that will actually render them in
//! production (`djangors_template::TemplateEngine`, MiniJinja), rather than eyeballed as source.
//! A template that fails to parse or references an undefined block fails this example.
//!
//! Run with:
//!
//! ```text
//! cargo run --example render_email_previews -- <output-dir>
//! ```

use std::path::PathBuf;

use djangors_template::TemplateEngine;
use serde_json::json;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let out_dir = PathBuf::from(
        std::env::args()
            .nth(1)
            .unwrap_or_else(|| "target/email-previews".to_string()),
    );
    std::fs::create_dir_all(&out_dir)?;

    // Footer values are supplied on every send by crate::infra::email_templates.
    let footer = json!({
        "asset_base_url": "https://assets.bloom.dev/email",
        "preferences_url": "https://cloud.bloom.dev/settings/notifications",
        "company_legal_name": "Bloom Technologies Ltd.",
        "company_address": "11 Adeola Odeku Street, Victoria Island, Lagos, Nigeria",
        "organization_name": "Acme Mobile",
    });

    let merge = |extra: serde_json::Value| -> serde_json::Value {
        let mut base = footer.clone();
        let (Some(b), Some(e)) = (base.as_object_mut(), extra.as_object()) else {
            unreachable!("both fixtures are objects")
        };
        for (k, v) in e {
            b.insert(k.clone(), v.clone());
        }
        base
    };

    let engine = TemplateEngine::new(vec![PathBuf::from("templates/emails")])?;
    let receipts = TemplateEngine::new(vec![PathBuf::from("templates/receipts")])?;

    let cases: Vec<(&str, serde_json::Value)> = vec![
        (
            "build_failed.html",
            merge(json!({
                "build_number": 142,
                "app_name": "Acme Delivery",
                "environment_name": "production",
                "platform": "Android",
                "git_branch": "main",
                "commit_short": "a3f91c2",
                "commit_message": "Add courier live-tracking sheet",
                "duration_human": "4m 12s",
                "failed_stage": "test",
                "collapsed_count": 2,
                "build_url": "https://cloud.bloom.dev/acme/delivery/builds/142",
                "log_excerpt": [
                    {"text": "00:03:51  Running 214 tests...", "is_error": false},
                    {"text": "00:04:02  ✓ 211 passed", "is_error": false},
                    {"text": "00:04:09  ✗ courier_tracking_test.dart: expected 3 stops, found 0", "is_error": true},
                    {"text": "Error: 3 tests failed. Exit code 1.", "is_error": true},
                ],
            })),
        ),
        (
            "deploy_succeeded.html",
            merge(json!({
                "app_name": "Acme Delivery",
                "environment_name": "production",
                "platform": "Flutter Web",
                "target": "web",
                "release_version": "v2.8.0",
                "previous_version": "v2.7.4",
                "commit_short": "a3f91c2",
                "duration_human": "1m 38s",
                "deployment_url": "https://delivery.acme.com",
                "dashboard_url": "https://cloud.bloom.dev/acme/delivery/deployments",
            })),
        ),
        (
            "billing_receipt.html",
            merge(json!({
                "receipt_number": "BLM-2026-000148",
                "issue_date": "1 August 2026",
                "period_start": "1 July 2026",
                "period_end": "31 July 2026",
                "billing_email": "billing@acme.com",
                "currency_code": "USD",
                "subtotal": "$118.00",
                "total": "$127.44",
                "payment_method": "Visa ending 4242",
                "provider_reference": "bchs_3PQ9xK2eZvKY",
                "receipt_pdf_url": "https://cloud.bloom.dev/acme/billing/receipts/BLM-2026-000148.pdf",
                "line_items": [
                    {"description": "Pro plan", "detail": "1 Jul – 31 Jul 2026 · 5 seats", "quantity": "1", "unit_amount": "$79.00", "amount": "$79.00"},
                    {"description": "Additional build minutes", "detail": "1,300 minutes over the 2,000 included", "quantity": "1,300", "unit_amount": "$0.02", "amount": "$26.00"},
                    {"description": "Web bandwidth", "detail": "130 GB over the 100 GB included", "quantity": "130", "unit_amount": "$0.10", "amount": "$13.00"},
                ],
                "tax_lines": [
                    {"label": "VAT", "rate": "8.0%", "amount": "$9.44"},
                ],
            })),
        ),
        (
            "org_invitation.html",
            merge(json!({
                "inviter_name": "Ada Okonkwo",
                "inviter_email": "ada@acme.com",
                "role": "Maintainer",
                "role_description": "trigger builds, approve releases, and manage environments",
                "accept_url": "https://cloud.bloom.dev/invitations/9f2c41ba",
                "expires_in_human": "7 days",
                "member_count": 6,
                "project_count": 3,
            })),
        ),
        (
            "promo_git_not_connected.html",
            merge(json!({
                "first_name": "Ada",
                "app_name": "Acme Delivery",
                "manual_build_count": 11,
                "connect_url": "https://cloud.bloom.dev/acme/settings/git",
                "docs_url": "https://bloom.dev/docs/cloud/git",
                "unsubscribe_url": "https://cloud.bloom.dev/u/6f1a9c3e2b",
            })),
        ),
    ];

    for (name, ctx) in &cases {
        let html = engine.render(name, ctx)?;
        assert!(
            html.len() < 102_400,
            "{name} is {} bytes; Gmail clips above 102KB and hides the unsubscribe link",
            html.len()
        );
        std::fs::write(out_dir.join(name), &html)?;
        println!("{name}: {} bytes", html.len());

        let text_name = name.replace(".html", ".txt");
        let text = engine.render(&text_name, ctx)?;
        assert!(!text.trim().is_empty(), "{text_name} rendered empty");
        std::fs::write(out_dir.join(&text_name), &text)?;
        println!("{text_name}: {} bytes", text.len());
    }

    let receipt = receipts.render(
        "receipt.html",
        json!({
            "asset_base_url": "https://assets.bloom.dev/email",
            "receipt_number": "BLM-2026-000148",
            "issue_date": "1 August 2026",
            "paid_at": "1 August 2026, 09:14 WAT",
            "period_start": "1 Jul 2026",
            "period_end": "31 Jul 2026",
            "currency_code": "USD",
            "company_legal_name": "Bloom Technologies Ltd.",
            "company_address_lines": ["11 Adeola Odeku Street", "Victoria Island, Lagos", "Nigeria"],
            "company_tax_id": "NG-TIN-20481937",
            "company_email": "billing@bloom.dev",
            "customer_name": "Acme Mobile Inc.",
            "customer_address_lines": ["500 Terry Francois Blvd", "San Francisco, CA 94158", "United States"],
            "customer_tax_id": "US-EIN-88-3921047",
            "customer_billing_email": "billing@acme.com",
            "subtotal": "$118.00",
            "total": "$127.44",
            "payment_method": "Visa ending 4242",
            "provider_reference": "bchs_3PQ9xK2eZvKY",
            "notes": "Thank you for building with Bloom.",
            "line_items": [
                {"description": "Pro plan", "detail": "1 Jul – 31 Jul 2026 · 5 seats", "quantity": "1", "unit_amount": "$79.00", "amount": "$79.00"},
                {"description": "Additional build minutes", "detail": "1,300 minutes over the 2,000 included", "quantity": "1,300", "unit_amount": "$0.02", "amount": "$26.00"},
                {"description": "Web bandwidth", "detail": "130 GB over the 100 GB included", "quantity": "130", "unit_amount": "$0.10", "amount": "$13.00"},
            ],
            "tax_lines": [{"label": "VAT", "rate": "8.0%", "amount": "$9.44"}],
        }),
    )?;
    std::fs::write(out_dir.join("receipt.html"), &receipt)?;
    println!("receipt.html: {} bytes", receipt.len());

    // A single self-contained validation page. The logo is inlined as a data URI so the gallery
    // renders with no network access at all, and each email sits in its own iframe so the
    // gallery's stylesheet cannot leak into markup that must survive a mail client untouched.
    let logo_data_uri = format!(
        "data:image/png;base64,{}",
        base64_encode(&std::fs::read("assets/email/bloom-petal.png")?)
    );
    let gallery = build_gallery(&out_dir, &cases, &receipt, &logo_data_uri)?;
    std::fs::write(out_dir.join("gallery.html"), &gallery)?;
    println!("gallery.html: {} bytes", gallery.len());

    println!("\nwrote previews to {}", out_dir.display());
    Ok(())
}

/// Minimal base64 for the inlined preview logo. Not used by production code, which relies on a
/// hosted asset URL; a data-URI logo in a real email trips spam filters.
fn base64_encode(bytes: &[u8]) -> String {
    const T: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);
    for chunk in bytes.chunks(3) {
        let b = [
            chunk[0],
            *chunk.get(1).unwrap_or(&0),
            *chunk.get(2).unwrap_or(&0),
        ];
        let n = (u32::from(b[0]) << 16) | (u32::from(b[1]) << 8) | u32::from(b[2]);
        for i in 0..4 {
            if i <= chunk.len() {
                out.push(T[((n >> (18 - 6 * i)) & 0x3F) as usize] as char);
            } else {
                out.push('=');
            }
        }
    }
    out
}

/// Escape a document for embedding in an `srcdoc` attribute.
fn srcdoc(html: &str) -> String {
    html.replace('&', "&amp;").replace('"', "&quot;")
}

/// Metadata shown above each rendered email, mirroring what the send path puts on the wire.
const ENVELOPES: &[(&str, &str, &str, &str)] = &[
    (
        "build.failed",
        "Bloom <notifications@bloom.dev>",
        "Build #142 failed — Acme Delivery (production)",
        "transactional",
    ),
    (
        "deploy.succeeded",
        "Bloom <notifications@bloom.dev>",
        "Acme Delivery v2.8.0 is live on production",
        "transactional",
    ),
    (
        "billing.receipt",
        "Bloom <notifications@bloom.dev>",
        "Receipt BLM-2026-000148 — $127.44 paid",
        "transactional",
    ),
    (
        "org.invitation",
        "Bloom <notifications@bloom.dev>",
        "Ada Okonkwo invited you to Acme Mobile",
        "transactional",
    ),
    (
        "promo.git_not_connected",
        "Bloom <hello@bloom.dev>",
        "You have started 11 builds by hand",
        "promotional",
    ),
];

fn build_gallery(
    out_dir: &std::path::Path,
    cases: &[(&str, serde_json::Value)],
    receipt: &str,
    logo: &str,
) -> Result<String, Box<dyn std::error::Error>> {
    let mut sections = String::new();

    for (idx, (name, _)) in cases.iter().enumerate() {
        let (key, from, subject, kind) = ENVELOPES[idx];
        let html = std::fs::read_to_string(out_dir.join(name))?
            .replace("https://assets.bloom.dev/email/bloom-petal.png", logo);
        let text = std::fs::read_to_string(out_dir.join(name.replace(".html", ".txt")))?;
        let unsub = if kind == "promotional" {
            "<span class=\"tag tag-on\">List-Unsubscribe</span>"
        } else {
            "<span class=\"tag tag-off\">no unsubscribe</span>"
        };
        sections.push_str(&format!(
            r#"<section class="card">
  <div class="meta">
    <div class="key">{key}</div>
    <dl>
      <div><dt>From</dt><dd class="mono">{from}</dd></div>
      <div><dt>Subject</dt><dd>{subject} <span class="count">{subject_len} chars</span></dd></div>
      <div><dt>Class</dt><dd>{kind} {unsub} <span class="tag tag-size">{size} KB</span></dd></div>
    </dl>
  </div>
  <div class="tabs"><button class="on" data-t="h">HTML</button><button data-t="p">Plain text</button></div>
  <div class="stage"><iframe class="pane h" title="{key} HTML" srcdoc="{doc}"></iframe><pre class="pane p" hidden>{plain}</pre></div>
</section>
"#,
            key = key,
            from = from,
            subject = subject,
            subject_len = subject.chars().count(),
            kind = kind,
            unsub = unsub,
            size = html.len() / 1024,
            doc = srcdoc(&html),
            plain = text.replace('&', "&amp;").replace('<', "&lt;"),
        ));
    }

    let receipt_doc =
        srcdoc(&receipt.replace("https://assets.bloom.dev/email/bloom-petal.png", logo));

    // Placeholder substitution rather than `format!`, because the shell is mostly CSS and every
    // literal brace would otherwise need doubling.
    Ok(include_str!("gallery_shell.html")
        .replace("<!--SECTIONS-->", &sections)
        .replace("RECEIPT_SRCDOC", &receipt_doc))
}
