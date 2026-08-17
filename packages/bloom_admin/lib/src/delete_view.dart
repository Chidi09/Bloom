import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_db/bloom_db.dart';
import 'admin_site.dart';
import 'csrf.dart';
import 'model_admin.dart';
import 'templates/admin_templates.dart';

/// Summary of related objects affected by a deletion action.
class BloomRelatedObjectSummary {
  /// App label containing the related model.
  final String appLabel;

  /// Struct name of the related model.
  final String structName;

  /// Relation field name linking to the deleted model.
  final String fieldName;

  /// Cascade / delete rule configured on the relation.
  final OnDelete onDelete;

  /// Number of related records affected.
  final int count;

  /// Nested cascade summaries for deeper relationships.
  final List<BloomRelatedObjectSummary> nested;

  /// Creates a [BloomRelatedObjectSummary] record.
  const BloomRelatedObjectSummary({
    required this.appLabel,
    required this.structName,
    required this.fieldName,
    required this.onDelete,
    required this.count,
    this.nested = const [],
  });
}

/// HTTP GET handler for rendering the single-object deletion confirmation page (`/:app/:model/:pk/delete/`).
Future<BloomResponse> deleteGetView({
  required BloomRequest request,
  required BloomModelAdmin admin,
  required DbExecutor db,
  required BloomSiteBranding branding,
  required AdminCsrf csrf,
}) async {
  final pkStr = request.params['pk'];
  final pk = int.tryParse(pkStr ?? '');
  if (pk == null) {
    return BloomResponse.notFound('Invalid object ID');
  }

  final obj = await admin.getByPk(db, pk);
  if (obj == null) {
    return BloomResponse.notFound('Object not found');
  }

  final fields = <Map<String, dynamic>>[];
  for (final entry in obj.entries) {
    fields.add({
      'name': entry.key,
      'value': entry.value?.toString() ?? '',
    });
  }

  final csrfToken = csrf.generateToken();

  final html = const DeleteConfirmTemplate().render({
    'fields': fields,
    'related': const [],
    'site_header': branding.siteHeader,
    'site_title': branding.siteTitle,
    'logo_url': branding.logoUrl,
    'accent_color': branding.accentColor,
    'csrf_token': csrfToken,
  });

  return BloomResponse.html(html);
}

/// HTTP POST handler for executing single-object deletion (`/:app/:model/:pk/delete/`).
Future<BloomResponse> deletePostView({
  required BloomRequest request,
  required BloomModelAdmin admin,
  required DbExecutor db,
  required AdminCsrf csrf,
}) async {
  final pkStr = request.params['pk'];
  final pk = int.tryParse(pkStr ?? '');
  if (pk == null) {
    return BloomResponse.notFound('Invalid object ID');
  }

  final formData = request.formData();
  if (!csrf.validateRequest(request, formData)) {
    return BloomResponse.forbidden('CSRF verification failed');
  }

  final deleted = await admin.deleteByPk(db, pk);
  if (!deleted) {
    return BloomResponse.notFound('Object not found or already deleted');
  }

  final app = admin.modelMeta.appLabel;
  final model = admin.modelMeta.structName.toLowerCase();
  return BloomResponse.redirect('/$app/$model/');
}

/// HTTP POST handler for rendering bulk delete confirmation or executing bulk deletion (`/:app/:model/bulk-delete/`).
Future<BloomResponse> bulkDeletePostView({
  required BloomRequest request,
  required BloomModelAdmin admin,
  required DbExecutor db,
  required BloomSiteBranding branding,
  required AdminCsrf csrf,
}) async {
  final rawBody = request.text();
  final formData = request.formData();

  if (!csrf.validateRequest(request, formData)) {
    return BloomResponse.forbidden('CSRF verification failed');
  }

  // Parse all `selected` values
  final pks = rawBody
      .split('&')
      .where((s) => s.startsWith('selected='))
      .map((s) => Uri.decodeQueryComponent(s.substring(9)))
      .map(int.tryParse)
      .whereType<int>()
      .toList();

  if (pks.isEmpty) {
    final app = admin.modelMeta.appLabel;
    final model = admin.modelMeta.structName.toLowerCase();
    return BloomResponse.redirect('/$app/$model/');
  }

  final isConfirm = formData['confirm'] == '1';

  if (!isConfirm) {
    // Step 1: Render bulk delete confirmation
    final items = <String>[];
    for (final pk in pks) {
      final obj = await admin.getByPk(db, pk);
      if (obj != null) {
        final repr = obj.entries.map((e) => '${e.key}: ${e.value}').join(', ');
        items.add(repr);
      }
    }

    final csrfToken = csrf.generateToken();
    final html = const BulkDeleteConfirmTemplate().render({
      'count': pks.length,
      'items': items,
      'pks': pks,
      'site_header': branding.siteHeader,
      'site_title': branding.siteTitle,
      'logo_url': branding.logoUrl,
      'accent_color': branding.accentColor,
      'csrf_token': csrfToken,
    });
    return BloomResponse.html(html);
  }

  // Step 2: Perform deletion
  for (final pk in pks) {
    await admin.deleteByPk(db, pk);
  }

  final app = admin.modelMeta.appLabel;
  final model = admin.modelMeta.structName.toLowerCase();
  return BloomResponse.redirect('/$app/$model/');
}

