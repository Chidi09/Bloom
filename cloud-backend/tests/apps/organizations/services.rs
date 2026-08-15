use std::str::FromStr;

use bloom_cloud_backend::apps::organizations::permissions::OrganizationRole;
use bloom_cloud_backend::apps::organizations::services::{
    generate_invite_token, slugify, INVITE_TTL_DAYS,
};

#[test]
fn test_slugify_logic() {
    assert_eq!(
        slugify("My Awesome Organization"),
        "my-awesome-organization"
    );
    assert_eq!(slugify("Acme, Inc.!"), "acme-inc");
    assert_eq!(slugify("  Spaces   &  Dashes--- "), "spaces-dashes");
    assert_eq!(slugify("123-numbers"), "123-numbers");
    assert_eq!(slugify(""), "org");
}

#[test]
fn test_invite_token_generation() {
    let token1 = generate_invite_token();
    let token2 = generate_invite_token();

    assert_eq!(token1.len(), 64);
    assert_eq!(token2.len(), 64);
    assert_ne!(token1, token2);
    assert!(token1.chars().all(|c| c.is_ascii_hexdigit()));
}

#[test]
fn test_role_hierarchy_and_parsing() {
    assert_eq!(
        OrganizationRole::from_str("owner").unwrap(),
        OrganizationRole::Owner
    );
    assert_eq!(
        OrganizationRole::from_str("admin").unwrap(),
        OrganizationRole::Admin
    );
    assert_eq!(
        OrganizationRole::from_str("release_manager").unwrap(),
        OrganizationRole::ReleaseManager
    );
    assert_eq!(
        OrganizationRole::from_str("developer").unwrap(),
        OrganizationRole::Developer
    );
    assert_eq!(
        OrganizationRole::from_str("viewer").unwrap(),
        OrganizationRole::Viewer
    );

    assert!(OrganizationRole::from_str("invalid_role").is_err());

    // Role hierarchy ordering: Viewer < Developer < ReleaseManager < Admin < Owner
    assert!(OrganizationRole::Viewer < OrganizationRole::Developer);
    assert!(OrganizationRole::Developer < OrganizationRole::ReleaseManager);
    assert!(OrganizationRole::ReleaseManager < OrganizationRole::Admin);
    assert!(OrganizationRole::Admin < OrganizationRole::Owner);
}

#[test]
fn test_invite_constants() {
    assert_eq!(INVITE_TTL_DAYS, 7);
}
