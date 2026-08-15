use bloom_cloud_backend::apps::apps::services::slugify;

#[test]
fn test_apps_slugify_logic() {
    assert_eq!(slugify("My Cool App"), "my-cool-app");
    assert_eq!(slugify("Bloom Mobile iOS"), "bloom-mobile-ios");
    assert_eq!(
        slugify("  Special   &  Characters--- "),
        "special-characters"
    );
    assert_eq!(slugify("123-numbers-only"), "123-numbers-only");
    assert_eq!(slugify(""), "app");
}
