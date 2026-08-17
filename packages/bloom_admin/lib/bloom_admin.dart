/// Automatic server-rendered HTML administration interface for Bloom applications.
///
/// Modeled on `djangors-admin` and Django's Admin interface, `bloom_admin` provides
/// introspective form and changelist generation from ORM metadata, real SQL database pagination,
/// auto-escaping template rendering, and cryptographic HMAC-SHA256 CSRF verification.
///
/// Example usage:
/// ```dart
/// import 'package:bloom_framework/bloom_framework.dart';
/// import 'package:bloom_db/bloom_db.dart';
/// import 'package:bloom_admin/bloom_admin.dart';
///
/// void main() async {
///   // 1. Initialize router and admin site
///   final router = BloomApiRouter();
///   final adminSite = BloomAdminSite()
///     .withSiteHeader('My Bloom App Admin')
///     .withSiteTitle('Bloom Control Center');
///
///   // 2. Register model with customized admin settings
///   adminSite.register<Article>(
///     meta: Article.meta,
///     fromRow: Article.fromRow,
///     config: const BloomModelAdminConfig(
///       listDisplay: ['id', 'title', 'isPublished'],
///       searchFields: ['title', 'content'],
///       listFilter: ['isPublished'],
///       listEditable: ['title'],
///     ),
///   );
///
///   // 3. Mount admin routes under /admin
///   final db = Database(config: DatabaseConfig(url: 'sqlite::memory:'));
///   adminSite.mount(router, db: db, basePath: '/admin');
///
///   // 4. Start serving HTTP requests
///   await router.serve(port: 8080);
/// }
/// ```
library bloom_admin;

export 'src/admin_site.dart';
export 'src/changelist_view.dart';
export 'src/csrf.dart';
export 'src/delete_view.dart';
export 'src/edit_view.dart';
export 'src/model_admin.dart';
export 'src/templates/admin_templates.dart';
export 'src/templates/template_engine.dart';

