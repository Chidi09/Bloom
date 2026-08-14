# `bloom generate`

Scaffolds strongly-typed architecture components, filesystem routes, state controllers, domain models, services, and routing tables according to Bloom design conventions.

---

## 💻 Synopsis

```bash
bloom generate <type> <name> [options]
```

### Supported Generator Types

| Subcommand | Alias | Target Output Directory | Description |
| :--- | :--- | :--- | :--- |
| `route` | `page` | `lib/routes/<name>.dart` | Creates a new filesystem route and updates `lib/app/routes.g.dart`. |
| `controller` | `ctrl` | `lib/features/<name>/<name>_controller.dart` | Creates a reactive `BloomController` with signals and lifecycle hooks. |
| `model` | `m` | `lib/models/<name>.dart` | Creates an immutable data class with `fromJson` and `toJson` methods. |
| `service` | `s` | `lib/services/<name>_service.dart` | Creates a business logic service injecting `BloomHttpClient`. |
| `router` | `r` | `lib/app/routes.g.dart` | Explicitly scans `lib/routes/` and regenerates the `GoRouter` table. |

---

## 🚀 Examples & Naming Rules

### 1. Generating a Route
```bash
bloom generate route dashboard
```
* **Creates:** `lib/routes/dashboard.dart` (`class DashboardRoute extends StatelessWidget`)
* **URL Match:** `/dashboard`

### 2. Generating a Dynamic Route with Path Parameter
```bash
bloom generate route users/[id]
```
* **Creates:** `lib/routes/users/[id].dart` (`class UsersIdRoute extends StatelessWidget`)
* **URL Match:** `/users/:id` (access parameter via `GoRouterState.of(context).pathParameters['id']`)

### 3. Generating a Controller
```bash
bloom generate controller auth
```
* **Creates:** `lib/features/auth/auth_controller.dart` (`class AuthController extends BloomController`)

### 4. Generating a Model
```bash
bloom generate model Product
```
* **Creates:** `lib/models/product.dart` (`class Product { ... }`)

### 5. Generating a Service
```bash
bloom generate service Product
```
* **Creates:** `lib/services/product_service.dart` (`class ProductService extends BloomRepository`)

---

## 🚪 Exit Codes

| Code | Meaning |
| :---: | :--- |
| **`0`** | Generator completed successfully and files written. |
| **`1`** | Failure: unknown generator type, missing component name, or invalid path. |
