use djangors_db::Database;
use djangors_migrations::{migrate, migrate_from_dir, MigrationError};
use std::path::Path;

/// Application migration directory reference.
#[derive(Debug, Clone, Copy)]
pub struct MigrationRef {
    /// Domain application name.
    pub app: &'static str,
    /// Path to the application migration directory.
    pub path: &'static str,
}

/// Ordered migration registry for Bloom Cloud backend applications.
/// Domain app migrations will be registered here in dependency order by subsequent phases.
pub const MIGRATIONS: &[MigrationRef] = &[
    MigrationRef {
        app: "accounts",
        path: "migrations/accounts",
    },
    // organizations depends on accounts (memberships reference users), so it is
    // registered after it. Order in this array is apply order.
    MigrationRef {
        app: "organizations",
        path: "migrations/organizations",
    },
    MigrationRef {
        app: "projects",
        path: "migrations/projects",
    },
    MigrationRef {
        app: "apps",
        path: "migrations/apps",
    },
    MigrationRef {
        app: "environments",
        path: "migrations/environments",
    },
    // Phase 2: credentials/signing are organization-scoped; secrets are
    // environment-scoped, so secrets is registered after environments.
    MigrationRef {
        app: "credentials",
        path: "migrations/credentials",
    },
    MigrationRef {
        app: "secrets",
        path: "migrations/secrets",
    },
    MigrationRef {
        app: "signing",
        path: "migrations/signing",
    },
    // Phase 3: events has no FK dependencies (it stores plain optional ids), so it applies
    // first; artifacts references builds, so builds precedes it.
    MigrationRef {
        app: "events",
        path: "migrations/events",
    },
    MigrationRef {
        app: "builds",
        path: "migrations/builds",
    },
    MigrationRef {
        app: "artifacts",
        path: "migrations/artifacts",
    },
    // Phase 4: releases reference artifacts; webhosting deployments reference both an
    // artifact and (optionally) a release, so it applies last.
    MigrationRef {
        app: "releases",
        path: "migrations/releases",
    },
    MigrationRef {
        app: "webhosting",
        path: "migrations/webhosting",
    },
    // Phase 5: deployments reference releases and artifacts; observability snapshots
    // reference releases, so both apply after those.
    MigrationRef {
        app: "deployments",
        path: "migrations/deployments",
    },
    MigrationRef {
        app: "observability",
        path: "migrations/observability",
    },
    // Phase 6: git connections are organization-scoped and independent; workflow runs
    // reference apps and environments, so they apply after those.
    MigrationRef {
        app: "git_connections",
        path: "migrations/git_connections",
    },
    MigrationRef {
        app: "workflows",
        path: "migrations/workflows",
    },
];

/// Applies all pending database migrations in registered sequence.
pub async fn run_migrations(db: &Database) -> Result<(), MigrationError> {
    let root_migrations_dir = Path::new("migrations");
    if root_migrations_dir.is_dir() {
        for migration in MIGRATIONS {
            let app_dir = Path::new(migration.path);
            if app_dir.is_dir() {
                migrate_from_dir(db, app_dir).await?;
            }
        }
        migrate_from_dir(db, root_migrations_dir).await?;
        Ok(())
    } else {
        migrate(db).await
    }
}
