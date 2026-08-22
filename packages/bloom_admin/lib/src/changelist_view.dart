import 'dart:convert';
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_db/bloom_db.dart';
import 'admin_site.dart';
import 'csrf.dart';
import 'model_admin.dart';
import 'templates/admin_templates.dart';

/// Default number of items displayed per page on admin changelist views.
const int changelistPerPage = 100;

/// Percent-encodes a value for query parameters.
String urlEncodeQueryValue(String s) => Uri.encodeQueryComponent(s);

/// Builds a `?key=value` query string from a map of parameter pairs.
String buildQueryString(Map<String, String?> pairs) {
  final parts = <String>[];
  for (final entry in pairs.entries) {
    if (entry.value != null && entry.value!.isNotEmpty) {
      parts.add('${entry.key}=${urlEncodeQueryValue(entry.value!)}');
    }
  }
  return parts.isEmpty ? '' : '?${parts.join('&')}';
}

/// Escapes a CSV field string according to RFC 4180 rules.
String csvEscapeField(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Formats changelist [columns] headers and [rows] data into a standard CSV string.
String rowsToCsv(List<String> columns, List<List<String>> rows) {
  final buffer = StringBuffer();
  buffer.writeln(columns.map(csvEscapeField).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(csvEscapeField).join(','));
  }
  return buffer.toString();
}

/// HTTP GET handler for rendering the model changelist table view.

Future<BloomResponse> changelistView({
  required BloomRequest request,
  required BloomModelAdmin admin,
  required DbExecutor db,
  required BloomSiteBranding branding,
  required AdminCsrf csrf,
}) async {
  final query = request.queryParams;
  final order = query['o'];
  final search = query['q'];
  final pageStr = query['page'];
  final page = pageStr != null ? (int.tryParse(pageStr) ?? 1) : 1;

  final activeFilters = <String, bool>{};
  for (final fieldName in admin.listFilterFields) {
    final val = query[fieldName];
    if (val == 'true') activeFilters[fieldName] = true;
    if (val == 'false') activeFilters[fieldName] = false;
  }

  final pageData = await admin.changelist(
    db: db,
    order: order,
    page: page,
    perPage: changelistPerPage,
    search: search,
    filters: activeFilters,
  );

  // Header cells
  final headerCells = <Map<String, dynamic>>[];
  for (final col in pageData.columns) {
    final newOrder = order == col ? '-$col' : col;
    final pairs = <String, String?>{
      'o': newOrder,
      'q': search,
      for (final f in activeFilters.entries) f.key: f.value ? 'true' : 'false',
    };
    headerCells.add({
      'href': buildQueryString(pairs),
      'label': col,
    });
  }

  // Row cells
  final rows = <Map<String, dynamic>>[];
  final editableFields = admin.listEditableFields;

  for (var i = 0; i < pageData.rows.length; i++) {
    final pk = pageData.pks[i];
    final rowVals = pageData.rows[i];
    final cells = <Map<String, dynamic>>[];

    for (var c = 0; c < rowVals.length; c++) {
      final colName = pageData.columns[c];
      final val = rowVals[c];

      if (c == 0) {
        cells.add({
          'kind': 'pk_link',
          'value': val,
          'field_name': colName,
        });
      } else if (editableFields.contains(colName)) {
        cells.add({
          'kind': 'editable',
          'value': val,
          'field_name': colName,
        });
      } else {
        cells.add({
          'kind': 'plain',
          'value': val,
          'field_name': colName,
        });
      }
    }
    rows.add({'pk': pk, 'cells': cells});
  }

  // Pagination
  final totalPages = (pageData.total / changelistPerPage).ceil();
  final prevHref = page > 1
      ? buildQueryString({
          'page': (page - 1).toString(),
          'o': order,
          'q': search,
          for (final f in activeFilters.entries) f.key: f.value ? 'true' : 'false',
        })
      : null;

  final nextHref = page < totalPages
      ? buildQueryString({
          'page': (page + 1).toString(),
          'o': order,
          'q': search,
          for (final f in activeFilters.entries) f.key: f.value ? 'true' : 'false',
        })
      : null;

  final pager = {
    'page': page,
    'total_pages': totalPages > 0 ? totalPages : 1,
    'total': pageData.total,
    'prev_href': prevHref,
    'next_href': nextHref,
  };

  // Search box
  final searchBox = {
    'visible': admin.searchFields.isNotEmpty,
    'q_value': search ?? '',
    'hidden_inputs': [
      if (order != null) {'name': 'o', 'value': order},
      for (final f in activeFilters.entries)
        {'name': f.key, 'value': f.value ? 'true' : 'false'},
    ],
  };

  // Filter blocks
  final filterBlocks = <Map<String, dynamic>>[];
  for (final fName in admin.listFilterFields) {
    filterBlocks.add({
      'field': fName,
      'all_href': buildQueryString({
        'o': order,
        'q': search,
        for (final f in activeFilters.entries)
          if (f.key != fName) f.key: f.value ? 'true' : 'false',
      }),
      'yes_href': buildQueryString({
        'o': order,
        'q': search,
        fName: 'true',
        for (final f in activeFilters.entries)
          if (f.key != fName) f.key: f.value ? 'true' : 'false',
      }),
      'no_href': buildQueryString({
        'o': order,
        'q': search,
        fName: 'false',
        for (final f in activeFilters.entries)
          if (f.key != fName) f.key: f.value ? 'true' : 'false',
      }),
    });
  }

  final exportQuery = buildQueryString({
    'o': order,
    'q': search,
    for (final f in activeFilters.entries) f.key: f.value ? 'true' : 'false',
  });

  final csrfToken = csrf.generateToken();

  final html = const ChangelistTemplate().render({
    'model_name': admin.modelMeta.structName,
    'site_header': branding.siteHeader,
    'site_title': branding.siteTitle,
    'logo_url': branding.logoUrl,
    'accent_color': branding.accentColor,
    'csrf_token': csrfToken,
    'has_add_permission': true,
    'has_change_permission': true,
    'has_delete_permission': true,
    'show_save_button': editableFields.isNotEmpty,
    'search': searchBox,
    'list_filter_blocks': filterBlocks,
    'header_cells': headerCells,
    'rows': rows,
    'actions': [
      for (final a in admin.actions) {'name': a.name, 'label': a.label}
    ],
    'pager': pager,
    'export_query': exportQuery,
  });

  return BloomResponse.html(html);
}

/// HTTP GET handler for exporting filtered model records as a CSV attachment.
Future<BloomResponse> exportCsvView({
  required BloomRequest request,
  required BloomModelAdmin admin,
  required DbExecutor db,
}) async {
  final query = request.queryParams;
  final order = query['o'];
  final search = query['q'];

  final activeFilters = <String, bool>{};
  for (final fieldName in admin.listFilterFields) {
    final val = query[fieldName];
    if (val == 'true') activeFilters[fieldName] = true;
    if (val == 'false') activeFilters[fieldName] = false;
  }

  final (cols, rows) = await admin.exportCsvRows(
    db: db,
    order: order,
    search: search,
    filters: activeFilters,
  );

  final csvContent = rowsToCsv(cols, rows);
  final filename = '${admin.modelMeta.structName.toLowerCase()}.csv';

  return BloomResponse(
    statusCode: 200,
    headers: {
      'content-type': 'text/csv; charset=utf-8',
      'content-disposition': 'attachment; filename="$filename"',
    },
    body: utf8.encode(csvContent),
  );
}

/// HTTP POST handler for saving multi-row inline edits from the changelist table.
Future<BloomResponse> saveChangelistView({
  required BloomRequest request,
  required BloomModelAdmin admin,
  required DbExecutor db,
  required AdminCsrf csrf,
}) async {
  final form = request.formData();
  if (!csrf.validateRequest(request, form)) {
    return BloomResponse.forbidden('CSRF verification failed');
  }

  // Parse edit-{pk}-{field} entries
  final pkEdits = <int, Map<String, String>>{};
  for (final entry in form.entries) {
    if (entry.key.startsWith('edit-')) {
      final parts = entry.key.substring(5).split('-');
      if (parts.length >= 2) {
        final pk = int.tryParse(parts[0]);
        final field = parts.sublist(1).join('-');
        if (pk != null) {
          pkEdits.putIfAbsent(pk, () => {})[field] = entry.value;
        }
      }
    }
  }

  for (final entry in pkEdits.entries) {
    await admin.updateFieldsFromForm(db, entry.key, entry.value);
  }

  final app = admin.modelMeta.appLabel;
  final model = admin.modelMeta.structName.toLowerCase();
  return BloomResponse.redirect('/$app/$model/');
}

/// HTTP POST handler for executing custom or bulk actions selected on the changelist table.
Future<BloomResponse> bulkActionView({
  required BloomRequest request,
  required BloomModelAdmin admin,
  required DbExecutor db,
  required AdminCsrf csrf,
}) async {
  final form = request.formData();
  if (!csrf.validateRequest(request, form)) {
    return BloomResponse.forbidden('CSRF verification failed');
  }

  final actionName = form['action'];
  final action = admin.actions.where((a) => a.name == actionName).firstOrNull;

  if (action != null) {
    // Parse selected PKs
    final rawPks = request.text().split('&').where((s) => s.startsWith('selected=')).map((s) => Uri.decodeQueryComponent(s.substring(9)));
    final pks = rawPks.map(int.tryParse).whereType<int>().toList();
    if (pks.isNotEmpty) {
      await action.handler(db, pks);
    }
  }

  final app = admin.modelMeta.appLabel;
  final model = admin.modelMeta.structName.toLowerCase();
  return BloomResponse.redirect('/$app/$model/');
}

