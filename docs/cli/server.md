# `bloom server` CLI Reference Manual

The `bloom server` command suite is the backend developer toolchain for scaffolding, running, and managing **Bloom Server** multi-isolate backend runtimes.

---

## 1. `bloom server run` — Multi-Isolate Server Runtime

Starts the multi-isolate backend server with automatic file watching and sub-80ms isolate hot restart.

```bash
bloom server run [options]
```

### Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `--watch, --no-watch` | Enables/disables recursive file watching and sub-second server restart. | `true` |
| `-p, --port <port>` | Server listening port. | `8080` |
| `-e, --entry <file>` | Server entrypoint Dart file. | `bin/server.dart` |

### Key Features
* **Multi-Isolate Concurrency**: Automatically distributes incoming HTTP and WebSocket connections across worker isolates matching host CPU cores.
* **Sub-80ms Hot Restart**: When backend routes, models, or controllers change, child isolates are re-spawned in `< 80ms` without dropping master TCP socket bindings or database pools.
* **Auto-Generated Documentation**: Exposes Scalar API explorer at `/api/docs` and Swagger UI at `/api/swagger`.

---

## 2. `bloom server create` — Scaffold Server Project

Scaffolds a new standalone Django-inspired Bloom Server backend project with core packages pre-wired.

```bash
bloom server create <project_name> [options]
```

### Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `--org <org_domain>` | Organization reverse-domain prefix. | `com.example` |
| `--packages-path <dir>` | Path to local `bloom_*` server packages. | Auto-detected |

### Scaffolded Architecture
```
my_server/
├── bin/
│   └── server.dart          # Multi-isolate bootstrap entrypoint
├── lib/
│   ├── apps/                # Django-style modular domain applications
│   ├── config/              # Environment & database configurations
│   ├── middleware/          # Authentication & error middlewares
│   └── urls.dart            # Master routing table (BloomApiRouter)
├── pubspec.yaml
└── .env
```

---

## 3. `bloom server startapp` — Scaffold Modular Domain App

Generates a modular Django-style domain application inside `lib/apps/<app_name>/` and automatically wires it into `lib/urls.dart`.

```bash
bloom server startapp <app_name>
```

### Generated File Structure
```
lib/apps/<app_name>/
├── controllers.dart   # Request handlers & JSON responses
├── models.dart        # Domain models & validation schemas
├── queries.dart       # Database queries & SQL repositories
└── urls.dart          # Local route registrations
```
