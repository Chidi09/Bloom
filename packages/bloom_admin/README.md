# bloom_admin

Automatic, server-rendered HTML administration interface for Bloom web applications, modeled on `djangors-admin` and Django's Admin interface.

## Features

- **Real Server-Side HTML Rendering**: Renders full HTML pages server-side directly into `BloomResponse.html(...)` response bodies.
- **Strict Auto-Escaping (Safe by Default)**: Built-in template rendering engine automatically escapes `<`, `>`, `&`, `"`, `'`, and `/` on all untrusted model and form inputs.
- **Introspective Form & Changelist Generation**: Inspects `bloom_db` runtime `ModelMeta` and `FieldMeta` to automatically determine column renderers, widget inputs (numbers, text, checkboxes, foreign keys), and validation rules.
- **Real Database Pagination**: Pagination is performed via `bloom_db` `limit`/`offset` SQL clauses on `QuerySet` (never in-memory slicing).
- **Cryptographic CSRF Verification**: Robust HMAC-SHA256 CSRF protection verified server-side on every state-changing POST/DELETE request.
- **Bulk Actions & In-place Changelist Editing**: Checkbox selection for bulk deletions, custom bulk action handlers, and multi-row inline edits.

---

## Architecture & Layout

```
lib/
  bloom_admin.dart                       # Barrel export
  src/
    admin_site.dart                      # BloomAdminSite central registry & route mounting
    model_admin.dart                     # BloomModelAdmin & DefaultBloomModelAdmin
    changelist_view.dart                 # Paginated list table & CSV export
    edit_view.dart                       # Add / change form rendering and submission
    delete_view.dart                     # Delete confirmation and execution
    csrf.dart                            # HMAC-SHA256 CSRF token generator & verifier
    templates/
      template_engine.dart               # SafeHtml wrapper & auto-escaping engine
      admin_templates.dart               # Server-rendered HTML templates
```

---

## Usage Example

### 1. Register a Model with `BloomAdminSite` and Mount to `BloomApiRouter`

```dart
import 'package:bloom_framework/bloom_framework.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_admin/bloom_admin.dart';

// Sample Model
class Article extends Model {
  final int id;
  final String title;
  final String content;
  final bool isPublished;

  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.isPublished,
  });

  static const meta = ModelMeta(
    structName: 'Article',
    appLabel: 'blog',
    tableName: 'blog_articles',
    fields: [
      FieldMeta(
        name: 'id',
        columnName: 'id',
        kind: FieldKind.integer,
        primaryKey: true,
        auto: true,
      ),
      FieldMeta(
        name: 'title',
        columnName: 'title',
        kind: FieldKind.char,
        maxLength: 255,
      ),
      FieldMeta(
        name: 'content',
        columnName: 'content',
        kind: FieldKind.text,
      ),
      FieldMeta(
        name: 'isPublished',
        columnName: 'is_published',
        kind: FieldKind.boolean,
      ),
    ],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
    ('id', BloomValue.integer(id)),
    ('title', BloomValue.text(title)),
    ('content', BloomValue.text(content)),
    ('isPublished', BloomValue.boolVal(isPublished)),
  ];

  static Article fromRow(DbRow row) {
    return Article(
      id: row.tryIntByName('id') ?? 0,
      title: row.tryStringByName('title') ?? '',
      content: row.tryStringByName('content') ?? '',
      isPublished: row.tryBoolByName('is_published') ?? false,
    );
  }
}

void main() async {
  // 1. Initialize router and admin site
  final router = BloomApiRouter();
  final adminSite = BloomAdminSite()
    .withSiteHeader('My Bloom App Admin')
    .withSiteTitle('Bloom Control Center');

  // 2. Register model with customized admin settings
  adminSite.register<Article>(
    meta: Article.meta,
    fromRow: Article.fromRow,
    config: const BloomModelAdminConfig(
      listDisplay: ['id', 'title', 'isPublished'],
      searchFields: ['title', 'content'],
      listFilter: ['isPublished'],
      listEditable: ['title'],
    ),
  );

  // 3. Mount admin routes under /admin
  final db = Database(config: DatabaseConfig(url: 'sqlite::memory:'));
  adminSite.mount(router, db: db, basePath: '/admin');

  // 4. Start serving HTTP requests
  await router.serve(port: 8080);
}
```

---

## Resulting Changelist Page Structure

When accessing `/admin/blog/article/`, the server renders full HTML with the following structure:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bloom Control Center</title>
  <style>/* Responsive styling, dark mode support, form and table layout */</style>
</head>
<body>
  <h1>My Bloom App Admin</h1>
  
  <!-- Search Toolbar -->
  <div class="search-bar">
    <form method="get">
      <input type="text" name="q" value="">
      <input type="submit" value="Search">
    </form>
  </div>

  <!-- Filter Sidebar / Bar -->
  <div class="filter-bar">
    <div class="filter-item">Filter by isPublished: <a href="?">All</a> | <a href="?isPublished=true">Yes</a> | <a href="?isPublished=false">No</a></div>
  </div>

  <div><a href="add/">Add Article</a></div>

  <!-- Main Changelist Table Form -->
  <form method="post" action="bulk-delete/">
    <input type="hidden" name="csrfmiddlewaretoken" value="eyJpZGVudGlmaWVyIjoi...">
    <table>
      <thead>
        <tr>
          <th><input type="checkbox" id="action-toggle"></th>
          <th><a href="?o=id">id</a></th>
          <th><a href="?o=title">title</a></th>
          <th><a href="?o=isPublished">isPublished</a></th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><input type="checkbox" name="selected" value="1"></td>
          <td><a href="1/change/">1</a></td>
          <td><input type="text" name="edit-1-title" value="Hello World"></td>
          <td>true</td>
        </tr>
      </tbody>
    </table>

    <!-- Actions & Buttons -->
    <div class="actions-bar">
      <select name="action">
        <option value="delete_selected">Delete selected</option>
      </select>
      <button type="submit" formaction="bulk-action/">Go</button>
      <button type="submit" formaction="bulk-delete/" class="btn-danger">Delete selected</button>
      <button type="submit" formaction="save-changelist/">Save</button>
    </div>

    <!-- Pagination & CSV Export -->
    <div>
      Page 1 of 1. Total: 1.
      <a href="export-csv/" style="margin-left: 1rem;">Export CSV</a>
    </div>
  </form>
</body>
</html>
```
