import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_db/bloom_db.dart';
import 'changelist_view.dart';
import 'csrf.dart';
import 'delete_view.dart';
import 'edit_view.dart';
import 'model_admin.dart';
import 'templates/admin_templates.dart';

/// Branding customization for the Bloom admin interface.
class BloomSiteBranding {
  /// Header title displayed at top left of admin pages.
  final String siteHeader;

  /// Browser window / tab title suffix.
  final String siteTitle;

  /// Optional custom logo image URL.
  final String? logoUrl;

  /// Optional custom CSS accent color hex string.
  final String? accentColor;

  /// Creates a [BloomSiteBranding] configuration with customizable header, title, logo, and accent color.
  const BloomSiteBranding({
    this.siteHeader = 'Bloom Administration',
    this.siteTitle = 'Bloom site admin',
    this.logoUrl,
    this.accentColor,
  });

  /// Creates a copy of this branding configuration with optional replaced properties.
  BloomSiteBranding copyWith({
    String? siteHeader,
    String? siteTitle,
    String? logoUrl,
    String? accentColor,
  }) {
    return BloomSiteBranding(
      siteHeader: siteHeader ?? this.siteHeader,
      siteTitle: siteTitle ?? this.siteTitle,
      logoUrl: logoUrl ?? this.logoUrl,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

/// Central administration site registry managing registered models and mounting admin routes.
///
/// Mirrors `djangors-admin`'s `AdminSite`.
class BloomAdminSite {
  final List<BloomModelAdmin> _registry = [];

  /// Branding customization applied to rendered administration templates.
  BloomSiteBranding branding;

  /// CSRF token generator and verifier for admin form requests.
  final AdminCsrf csrf;

  /// Creates a [BloomAdminSite] with optional [branding] settings and [csrf] manager.
  BloomAdminSite({
    BloomSiteBranding? branding,
    AdminCsrf? csrf,
  })  : branding = branding ?? const BloomSiteBranding(),
        csrf = csrf ?? AdminCsrf();


  /// Sets the admin site header text.
  BloomAdminSite withSiteHeader(String header) {
    branding = branding.copyWith(siteHeader: header);
    return this;
  }

  /// Sets the admin site title text.
  BloomAdminSite withSiteTitle(String title) {
    branding = branding.copyWith(siteTitle: title);
    return this;
  }

  /// Sets a custom logo URL for the admin site header.
  BloomAdminSite withLogoUrl(String url) {
    branding = branding.copyWith(logoUrl: url);
    return this;
  }

  /// Sets a custom CSS accent color for the admin site.
  BloomAdminSite withAccentColor(String color) {
    branding = branding.copyWith(accentColor: color);
    return this;
  }

  /// Registers a custom [BloomModelAdmin] in the admin site registry.
  void registerAdmin(BloomModelAdmin admin) {
    _registry.add(admin);
  }

  /// Registers a model [T] with optional [BloomModelAdminConfig].
  void register<T extends Model>({
    required ModelMeta meta,
    required ModelFromRow<T> fromRow,
    BloomModelAdminConfig config = const BloomModelAdminConfig(),
  }) {
    _registry.add(DefaultBloomModelAdmin<T>(
      meta: meta,
      fromRow: fromRow,
      config: config,
    ));
  }

  /// Looks up a registered [BloomModelAdmin] by app label and model slug/name.
  BloomModelAdmin? findAdmin(String appLabel, String modelName) {
    final lower = modelName.toLowerCase();
    for (final admin in _registry) {
      if (admin.modelMeta.appLabel == appLabel &&
          (admin.modelMeta.structName.toLowerCase() == lower ||
              admin.modelMeta.tableName.toLowerCase() == lower)) {
        return admin;
      }
    }
    return null;
  }

  /// Mounts the administration site routes onto a [BloomApiRouter].
  ///
  /// [db] provides the database connection / executor for ORM operations.
  /// [basePath] is the prefix under which admin routes are mounted (e.g. `""` or `"/admin"`).
  void mount(BloomApiRouter router, {required DbExecutor db, String basePath = ''}) {
    final prefix = basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;

    // Index / Dashboard View
    router.get('$prefix/', (req) async {
      final models = <Map<String, dynamic>>[];
      for (final admin in _registry) {
        final meta = admin.modelMeta;
        models.add({
          'href': '$prefix/${meta.appLabel}/${meta.structName.toLowerCase()}/',
          'label': '${meta.appLabel}.${meta.structName}',
          'has_view_permission': true,
          'has_change_permission': true,
          'has_add_permission': true,
        });
      }

      final html = const IndexTemplate().render({
        'models': models,
        'recent_actions': const <dynamic>[],
        'site_header': branding.siteHeader,
        'site_title': branding.siteTitle,
        'logo_url': branding.logoUrl,
        'accent_color': branding.accentColor,
      });

      return BloomResponse.html(html);
    });

    // Changelist / Table View
    router.get('$prefix/:app/:model/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return changelistView(
        request: req,
        admin: admin,
        db: db,
        branding: branding,
        csrf: csrf,
      );
    });

    // CSV Export
    router.get('$prefix/:app/:model/export-csv/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return exportCsvView(
        request: req,
        admin: admin,
        db: db,
      );
    });

    // Add GET
    router.get('$prefix/:app/:model/add/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return addGetView(
        request: req,
        admin: admin,
        db: db,
        branding: branding,
        csrf: csrf,
      );
    });

    // Add POST
    router.post('$prefix/:app/:model/add/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return addPostView(
        request: req,
        admin: admin,
        db: db,
        branding: branding,
        csrf: csrf,
      );
    });

    // Change GET
    router.get('$prefix/:app/:model/:pk/change/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return changeGetView(
        request: req,
        admin: admin,
        db: db,
        branding: branding,
        csrf: csrf,
      );
    });

    // Change POST
    router.post('$prefix/:app/:model/:pk/change/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return changePostView(
        request: req,
        admin: admin,
        db: db,
        branding: branding,
        csrf: csrf,
      );
    });

    // Delete GET
    router.get('$prefix/:app/:model/:pk/delete/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return deleteGetView(
        request: req,
        admin: admin,
        db: db,
        branding: branding,
        csrf: csrf,
      );
    });

    // Delete POST
    router.post('$prefix/:app/:model/:pk/delete/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return deletePostView(
        request: req,
        admin: admin,
        db: db,
        csrf: csrf,
      );
    });

    // Bulk Delete POST
    router.post('$prefix/:app/:model/bulk-delete/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return bulkDeletePostView(
        request: req,
        admin: admin,
        db: db,
        branding: branding,
        csrf: csrf,
      );
    });

    // Save Changelist POST
    router.post('$prefix/:app/:model/save-changelist/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return saveChangelistView(
        request: req,
        admin: admin,
        db: db,
        csrf: csrf,
      );
    });

    // Bulk Action POST
    router.post('$prefix/:app/:model/bulk-action/', (req) async {
      final admin = findAdmin(req.params['app'] ?? '', req.params['model'] ?? '');
      if (admin == null) return BloomResponse.notFound('Admin model not found');
      return bulkActionView(
        request: req,
        admin: admin,
        db: db,
        csrf: csrf,
      );
    });
  }
}
