import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_db/bloom_db.dart';
import 'admin_site.dart';
import 'csrf.dart';
import 'model_admin.dart';
import 'templates/admin_templates.dart';

/// Form view renderer helper.
Future<BloomResponse> _renderFormView({
  required BloomModelAdmin admin,
  required Map<String, dynamic> initialValues,
  required Map<String, String> errors,
  required bool isAdd,
  required BloomSiteBranding branding,
  required AdminCsrf csrf,
}) async {
  final meta = admin.modelMeta;
  final rows = <Map<String, dynamic>>[];
  final fieldsets = admin.fieldsets;
  final readonlyFields = admin.readonlyFields;
  final rawIdFields = admin.rawIdFields;

  Map<String, dynamic>? buildRow(String name, String? section) {
    final field = meta.findField(name);
    if (field != null) {
      if (field.auto || field.primaryKey) {
        if (isAdd) return null;
        return {
          'kind': 'readonly',
          'name': name,
          'value': initialValues[name]?.toString() ?? '',
          'checked': false,
          'error': null,
          'section': section,
          'lookup_href': null,
        };
      }

      final val = initialValues[name]?.toString() ?? '';
      final isReadonly = readonlyFields.contains(name);
      final kind = isReadonly
          ? 'readonly'
          : (field.kind == FieldKind.boolean
              ? 'checkbox'
              : (field.kind == FieldKind.integer ||
                      field.kind == FieldKind.bigInt ||
                      field.kind == FieldKind.float ||
                      field.kind is DecimalFieldKind
                  ? 'number'
                  : 'text'));

      final isChecked = kind == 'checkbox' && (val == 'true' || val == 'on' || val == '1');

      return {
        'kind': kind,
        'name': name,
        'value': val,
        'checked': isChecked,
        'error': errors[name],
        'section': section,
        'lookup_href': null,
      };
    }

    final rel = meta.relations.where((r) => r.fieldName == name).firstOrNull;
    if (rel != null) {
      final val = initialValues[name]?.toString() ?? '';
      final isReadonly = readonlyFields.contains(name);
      final kind = isReadonly ? 'readonly' : 'number';

      String? lookupHref;
      if (rawIdFields.contains(name)) {
        final targetMeta = rel.target();
        lookupHref = '/${targetMeta.appLabel}/${targetMeta.structName.toLowerCase()}/';
      }

      return {
        'kind': kind,
        'name': name,
        'value': val,
        'checked': false,
        'error': errors[name],
        'section': section,
        'lookup_href': lookupHref,
      };
    }

    return null;
  }

  if (fieldsets != null && fieldsets.isNotEmpty) {
    final handledFields = <String>{};
    for (final (sectionTitle, fields) in fieldsets) {
      for (final fName in fields) {
        handledFields.add(fName);
        final r = buildRow(fName, sectionTitle);
        if (r != null) rows.add(r);
      }
    }
    for (final fName in admin.fieldNames) {
      if (!handledFields.contains(fName)) {
        final r = buildRow(fName, null);
        if (r != null) rows.add(r);
      }
    }
  } else {
    for (final fName in admin.fieldNames) {
      final r = buildRow(fName, null);
      if (r != null) rows.add(r);
    }
  }

  final csrfToken = csrf.generateToken();

  final html = const EditFormTemplate().render({
    'rows': rows,
    'inlines': const <dynamic>[],
    'site_header': branding.siteHeader,
    'site_title': branding.siteTitle,
    'logo_url': branding.logoUrl,
    'accent_color': branding.accentColor,
    'csrf_token': csrfToken,
    'has_change_permission': true,
    'has_delete_permission': true,
    'is_add': isAdd,
  });

  return BloomResponse.html(html);
}

/// HTTP GET handler for rendering the model creation form (`/:app/:model/add/`).
Future<BloomResponse> addGetView({
  required BloomRequest request,
  required BloomModelAdmin admin,
  required DbExecutor db,
  required BloomSiteBranding branding,
  required AdminCsrf csrf,
}) async {
  return _renderFormView(
    admin: admin,
    initialValues: {},
    errors: {},
    isAdd: true,
    branding: branding,
    csrf: csrf,
  );
}

/// HTTP POST handler for processing a new model creation form submission (`/:app/:model/add/`).
Future<BloomResponse> addPostView({
  required BloomRequest request,
  required BloomModelAdmin admin,
  required DbExecutor db,
  required BloomSiteBranding branding,
  required AdminCsrf csrf,
}) async {
  final formData = request.formData();
  if (!csrf.validateRequest(request, formData)) {
    return BloomResponse.forbidden('CSRF verification failed');
  }

  final (newPk, errors) = await admin.createFromForm(db, formData);
  if (errors != null) {
    return _renderFormView(
      admin: admin,
      initialValues: formData,
      errors: errors,
      isAdd: true,
      branding: branding,
      csrf: csrf,
    );
  }

  final app = admin.modelMeta.appLabel;
  final model = admin.modelMeta.structName.toLowerCase();
  return BloomResponse.redirect('/$app/$model/');
}

/// HTTP GET handler for rendering the model modification form (`/:app/:model/:pk/change/`).
Future<BloomResponse> changeGetView({
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

  return _renderFormView(
    admin: admin,
    initialValues: obj,
    errors: {},
    isAdd: false,
    branding: branding,
    csrf: csrf,
  );
}

/// HTTP POST handler for saving updates submitted from a model edit form (`/:app/:model/:pk/change/`).
Future<BloomResponse> changePostView({
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

  final formData = request.formData();
  if (!csrf.validateRequest(request, formData)) {
    return BloomResponse.forbidden('CSRF verification failed');
  }

  final errors = await admin.updateFromForm(db, pk, formData);
  if (errors != null) {
    final existing = await admin.getByPk(db, pk) ?? {};
    final merged = {...existing, ...formData};
    return _renderFormView(
      admin: admin,
      initialValues: merged,
      errors: errors,
      isAdd: false,
      branding: branding,
      csrf: csrf,
    );
  }

  final app = admin.modelMeta.appLabel;
  final model = admin.modelMeta.structName.toLowerCase();
  return BloomResponse.redirect('/$app/$model/');
}

