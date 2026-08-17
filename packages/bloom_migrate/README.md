# bloom_migrate

Database migrations CLI and runtime library for Bloom applications built on `bloom_db`.

`bloom_migrate` generates dialect-accurate DDL SQL files (`-- up` and `-- down` sections) from `@BloomModel` / `ModelMeta` definitions and provides a transactional migration runner with migration tracking.

---

## Migration File Convention

Migration files follow the monorepo's standard convention used in `cloud-backend`:
`migrations/<app>/NNNN_name.sql`

Example: `migrations/accounts/0001_initial.sql`

```sql
-- up
CREATE TABLE accounts_userprofile (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    display_name VARCHAR(255),
    timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- down
DROP TABLE accounts_userprofile;
```

---

## FieldKind to SQL Type Mapping Table

| `FieldKind` | PostgreSQL Type | SQLite Type |
|---|---|---|
| `char` | `VARCHAR(maxLength ?? 255)` | `TEXT` |
| `text` | `TEXT` | `TEXT` |
| `fileField` | `VARCHAR(maxLength ?? 500)` | `TEXT` |
| `integer` | `INTEGER` (or `SERIAL` if `auto`) | `INTEGER` (`AUTOINCREMENT` if `auto && primaryKey`) |
| `bigInt` | `BIGINT` (or `BIGSERIAL` if `auto`) | `INTEGER` (`AUTOINCREMENT` if `auto && primaryKey`) |
| `float` | `DOUBLE PRECISION` | `REAL` |
| `boolean` | `BOOLEAN` | `INTEGER` |
| `date` | `DATE` | `TEXT` |
| `dateTime` | `TIMESTAMPTZ` | `TEXT` |
| `time` | `TIME` | `TEXT` |
| `duration` | `INTERVAL` | `TEXT` |
| `uuid` | `UUID` | `TEXT` |
| `email` | `VARCHAR(maxLength ?? 254)` | `TEXT` |
| `url` | `VARCHAR(maxLength ?? 2000)` | `TEXT` |
| `slug` | `VARCHAR(maxLength ?? 50)` | `TEXT` |
| `ip` | `INET` | `TEXT` |
| `binary` | `BYTEA` | `BLOB` |
| `json` | `JSONB` | `TEXT` |
| `decimal(p, s)` | `NUMERIC(precision, scale)` | `NUMERIC` |

---

## Migration Tracking Table Schema

Applied migrations are tracked in the `bloom_migrations` table:

```sql
-- PostgreSQL
CREATE TABLE IF NOT EXISTS bloom_migrations (
    id BIGSERIAL PRIMARY KEY,
    app VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uniq_bloom_migrations_app_name UNIQUE (app, name)
);

-- SQLite
CREATE TABLE IF NOT EXISTS bloom_migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app TEXT NOT NULL,
    name TEXT NOT NULL,
    applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uniq_bloom_migrations_app_name UNIQUE (app, name)
);
```

---

## Full Workflow Example

### 1. Define Models with `bloom_db`

```dart
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_migrate/bloom_migrate.dart';

const userProfileMeta = ModelMeta(
  structName: 'UserProfile',
  appLabel: 'accounts',
  tableName: 'accounts_userprofile',
  fields: [
    FieldMeta(
      name: 'id',
      columnName: 'id',
      kind: FieldKind.bigInt,
      primaryKey: true,
      auto: true,
    ),
    FieldMeta(
      name: 'userId',
      columnName: 'user_id',
      kind: FieldKind.bigInt,
      unique: true,
    ),
    FieldMeta(
      name: 'displayName',
      columnName: 'display_name',
      kind: FieldKind.char,
      maxLength: 255,
      nullable: true,
    ),
    FieldMeta(
      name: 'createdAt',
      columnName: 'created_at',
      kind: FieldKind.dateTime,
      defaultVal: DefaultValue.none(),
    ),
  ],
  indexes: [
    IndexMeta(
      name: 'accounts_userprofile_user_id_idx',
      fields: ['user_id'],
    ),
  ],
);

void main() {
  // Register model metadata
  BloomModelRegistry.instance.register(userProfileMeta);
}
```

### 2. Run `makemigrations`

> **Note on Migration Generation Scope:**
> `makemigrations` in this release generates full `--initial` schema creation files from registered models, resolving foreign key dependency ordering and index definitions. Incremental AST/snapshot schema drift diffing is a planned follow-up.

```bash
# Generate initial migration for 'accounts' targeting PostgreSQL
dart run bloom_migrate makemigrations accounts --dialect=postgres --name=initial
```

Output:
```
Created migration: migrations/accounts/0001_initial.sql
```

### 3. Inspect the Generated `.sql` File

File `migrations/accounts/0001_initial.sql`:

```sql
-- up
CREATE TABLE IF NOT EXISTS accounts_userprofile (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    display_name VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS accounts_userprofile_user_id_idx ON accounts_userprofile(user_id);

-- down
DROP TABLE IF EXISTS accounts_userprofile;
```

### 4. Apply Migrations (`migrate`)

```bash
# Apply pending migrations against PostgreSQL
dart run bloom_migrate migrate --url=postgres://user:password@localhost:5432/bloom_dev

# Or apply against local SQLite database
dart run bloom_migrate migrate --url=sqlite:bloom.db
```

Output:
```
Connecting to database...
Applying 1 pending migration(s)...
  ✓ Applied accounts/0001_initial
Migration complete. 1 migration(s) applied.
```

### 5. Check Migration Status

```bash
dart run bloom_migrate status --url=sqlite:bloom.db
```

Output:
```
=== Migration Status ===
Tracking Table: bloom_migrations

Applied migrations:
  [X] accounts/0001_initial (at 2026-08-17T15:42:00.000Z)
```

### 6. Roll Back Migrations (`rollback`)

```bash
dart run bloom_migrate rollback --url=sqlite:bloom.db --count=1
```

Output:
```
Connecting to database...
Rolling back 1 migration(s)...
  ↺ Rolled back accounts/0001_initial
Rollback complete. 1 migration(s) undone.
```

---

## Programmatic API Usage

You can also embed the migration runner directly within backend startup code:

```dart
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_migrate/bloom_migrate.dart';

Future<void> runStartupMigrations(DbExecutor db) async {
  final runner = MigrationRunner(
    db: db,
    migrationsDirectory: 'migrations',
  );

  final applied = await runner.migrate();
  for (final m in applied) {
    print('Applied startup migration: ${m.app}/${m.name}');
  }
}
```
