import 'template_engine.dart';

/// Base layout HTML template for `bloom_admin`.
class BaseTemplate implements AdminTemplate {
  /// Creates a [BaseTemplate] instance.
  const BaseTemplate();


  @override
  String render(Map<String, dynamic> context) {
    final title = htmlEscape(context['site_title']?.toString() ?? 'Bloom site admin');
    final siteHeader = htmlEscape(context['site_header']?.toString() ?? 'Bloom Administration');
    final accentColor = context['accent_color'] != null
        ? htmlEscape(context['accent_color'].toString())
        : null;
    final logoUrl = context['logo_url']?.toString();
    final bodyContent = context['body'] is SafeHtml
        ? (context['body'] as SafeHtml).rawHtml
        : htmlEscape(context['body']?.toString() ?? '');

    final accentStyle = accentColor != null ? '<style>:root { --accent: $accentColor; }</style>' : '';
    final logoTag = logoUrl != null
        ? '<img src="${htmlEscape(logoUrl)}" alt="" class="site-logo">'
        : '';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<style>
:root {
  --bg: #ffffff;
  --fg: #111827;
  --muted: #6b7280;
  --accent: #2563eb;
  --border: #d1d5db;
  --input-bg: #ffffff;
  --row-alt: #f9fafb;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0f1115;
    --fg: #e5e7eb;
    --muted: #9ca3af;
    --accent: #60a5fa;
    --border: #374151;
    --input-bg: #1a1d23;
    --row-alt: #16181d;
  }
}
* { box-sizing: border-box; }
body {
  background: var(--bg);
  color: var(--fg);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  margin: 0;
  padding: 2rem;
  line-height: 1.5;
}
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
th, td { border: 1px solid var(--border); padding: 0.5rem 0.75rem; text-align: left; }
th { background: var(--row-alt); }
tbody tr:nth-child(even) { background: var(--row-alt); }
input, button, select { font: inherit; color: inherit; }
input[type="text"], input[type="number"], input[type="password"], input[type="email"], select {
  background: var(--input-bg);
  border: 1px solid var(--border);
  border-radius: 4px;
  padding: 0.35rem 0.5rem;
  color: var(--fg);
}
button, input[type="submit"] {
  background: var(--accent);
  color: #ffffff;
  border: none;
  border-radius: 4px;
  padding: 0.4rem 0.9rem;
  cursor: pointer;
}
button:hover, input[type="submit"]:hover { opacity: 0.9; }
.btn-danger {
  background: #dc2626 !important;
}
.actions-bar {
  margin: 1rem 0;
  display: flex;
  gap: 0.5rem;
  align-items: center;
}
.filter-bar {
  margin: 0.5rem 0;
}
.filter-item {
  display: inline-block;
  margin-right: 1rem;
}
.search-bar {
  margin: 1rem 0;
}
.date-hierarchy { margin: 0.5rem 0; color: var(--muted); }
h1 { font-size: 1.25rem; margin: 0 0 1rem; }
.site-logo { height: 1.5em; vertical-align: middle; margin-right: 0.5rem; }
.form-row {
  margin-bottom: 1rem;
}
.form-row label {
  display: block;
  font-weight: 500;
  margin-bottom: 0.25rem;
}
.form-error {
  color: #dc2626;
  font-size: 0.875rem;
  margin-top: 0.25rem;
}
fieldset {
  border: 1px solid var(--border);
  border-radius: 4px;
  margin-bottom: 1.5rem;
  padding: 1rem;
}
legend {
  font-weight: bold;
  padding: 0 0.5rem;
}
</style>
$accentStyle
</head>
<body>
<h1>$logoTag$siteHeader</h1>
$bodyContent
</body>
</html>
''';
  }
}

/// Index / Dashboard HTML template.
class IndexTemplate implements AdminTemplate {
  /// Creates an [IndexTemplate] instance.
  const IndexTemplate();

  @override
  String render(Map<String, dynamic> context) {
    final models = context['models'] as List<dynamic>? ?? const [];
    final recentActions = context['recent_actions'] as List<dynamic>? ?? const [];

    final buffer = StringBuffer();
    buffer.write('<ul>\n');
    for (final m in models) {
      final href = htmlEscape(m['href']?.toString() ?? '');
      final label = htmlEscape(m['label']?.toString() ?? '');
      final hasView = m['has_view_permission'] == true;
      final hasChange = m['has_change_permission'] == true;
      final hasAdd = m['has_add_permission'] == true;

      if (hasView || hasChange || hasAdd) {
        buffer.write('  <li><a href="$href">$label</a></li>\n');
      }
    }
    buffer.write('</ul>\n');

    if (recentActions.isNotEmpty) {
      buffer.write('<h2>Recent actions</h2>\n<ul>\n');
      for (final a in recentActions) {
        final time = htmlEscape(a['action_time']?.toString() ?? '');
        final label = htmlEscape(a['action_label']?.toString() ?? '');
        final appLabel = htmlEscape(a['app_label']?.toString() ?? '');
        final modelName = htmlEscape(a['model_name']?.toString() ?? '');
        final repr = htmlEscape(a['object_repr']?.toString() ?? '');
        buffer.write('  <li>$time — $label $appLabel.$modelName: $repr</li>\n');
      }
      buffer.write('</ul>\n');
    }

    final fullContext = Map<String, dynamic>.from(context);
    fullContext['body'] = SafeHtml(buffer.toString());
    return const BaseTemplate().render(fullContext);
  }
}

/// Changelist / Table HTML template.
class ChangelistTemplate implements AdminTemplate {
  /// Creates a [ChangelistTemplate] instance.
  const ChangelistTemplate();

  @override
  String render(Map<String, dynamic> context) {
    final buffer = StringBuffer();

    final modelName = htmlEscape(context['model_name']?.toString() ?? 'Object');
    final hasAdd = context['has_add_permission'] == true;
    final hasDelete = context['has_delete_permission'] == true;
    final hasChange = context['has_change_permission'] == true;
    final showSave = context['show_save_button'] == true;
    final csrfToken = htmlEscape(context['csrf_token']?.toString() ?? '');

    // Search bar
    final search = context['search'] as Map<String, dynamic>?;
    if (search != null && search['visible'] == true) {
      buffer.write('<div class="search-bar">\n<form method="get">\n');
      final hiddenInputs = search['hidden_inputs'] as List<dynamic>? ?? const [];
      for (final h in hiddenInputs) {
        final hName = htmlEscape(h['name']?.toString() ?? '');
        final hVal = htmlEscape(h['value']?.toString() ?? '');
        buffer.write('  <input type="hidden" name="$hName" value="$hVal">\n');
      }
      final qVal = htmlEscape(search['q_value']?.toString() ?? '');
      buffer.write('  <input type="text" name="q" value="$qVal"> <input type="submit" value="Search">\n');
      buffer.write('</form>\n</div>\n');
    }

    // List filters
    final filterBlocks = context['list_filter_blocks'] as List<dynamic>? ?? const [];
    if (filterBlocks.isNotEmpty) {
      buffer.write('<div class="filter-bar">\n');
      for (final f in filterBlocks) {
        final field = htmlEscape(f['field']?.toString() ?? '');
        final allHref = htmlEscape(f['all_href']?.toString() ?? '');
        final yesHref = htmlEscape(f['yes_href']?.toString() ?? '');
        final noHref = htmlEscape(f['no_href']?.toString() ?? '');
        buffer.write('  <div class="filter-item">Filter by $field: <a href="$allHref">All</a> | <a href="$yesHref">Yes</a> | <a href="$noHref">No</a></div>\n');
      }
      buffer.write('</div>\n');
    }

    if (hasAdd) {
      buffer.write('<div><a href="add/">Add $modelName</a></div>\n');
    }

    // Main changelist form
    buffer.write('<form method="post" action="bulk-delete/">\n');
    buffer.write('  <input type="hidden" name="csrfmiddlewaretoken" value="$csrfToken">\n');
    buffer.write('  <table>\n    <thead>\n      <tr>\n        <th><input type="checkbox" id="action-toggle" onclick="document.querySelectorAll(\'tbody input[type=checkbox]\').forEach(c=>c.checked=this.checked)"></th>\n');

    final headerCells = context['header_cells'] as List<dynamic>? ?? const [];
    for (final h in headerCells) {
      final href = htmlEscape(h['href']?.toString() ?? '');
      final label = htmlEscape(h['label']?.toString() ?? '');
      buffer.write('        <th><a href="$href">$label</a></th>\n');
    }
    buffer.write('      </tr>\n    </thead>\n    <tbody>\n');

    final rows = context['rows'] as List<dynamic>? ?? const [];
    for (final row in rows) {
      final pk = htmlEscape(row['pk']?.toString() ?? '');
      final cells = row['cells'] as List<dynamic>? ?? const [];
      buffer.write('      <tr>\n        <td><input type="checkbox" name="selected" value="$pk"></td>\n');

      for (final cell in cells) {
        final kind = cell['kind']?.toString() ?? 'plain';
        final val = htmlEscape(cell['value']?.toString() ?? '');
        final fieldName = htmlEscape(cell['field_name']?.toString() ?? '');

        if (kind == 'pk_link') {
          buffer.write('        <td><a href="$pk/change/">$val</a></td>\n');
        } else if (kind == 'editable') {
          buffer.write('        <td><input type="text" name="edit-$pk-$fieldName" value="$val"></td>\n');
        } else {
          buffer.write('        <td>$val</td>\n');
        }
      }
      buffer.write('      </tr>\n');
    }
    buffer.write('    </tbody>\n  </table>\n');

    // Actions & Buttons
    final actions = context['actions'] as List<dynamic>? ?? const [];
    buffer.write('  <div class="actions-bar">\n');
    if ((hasDelete || hasChange) && actions.isNotEmpty) {
      buffer.write('    <select name="action">\n');
      for (final a in actions) {
        final aName = htmlEscape(a['name']?.toString() ?? '');
        final aLabel = htmlEscape(a['label']?.toString() ?? '');
        buffer.write('      <option value="$aName">$aLabel</option>\n');
      }
      buffer.write('    </select>\n');
      buffer.write('    <button type="submit" formaction="bulk-action/">Go</button>\n');
    }
    if (hasDelete) {
      buffer.write('    <button type="submit" formaction="bulk-delete/" class="btn-danger">Delete selected</button>\n');
    }
    if (hasChange && showSave) {
      buffer.write('    <button type="submit" formaction="save-changelist/">Save</button>\n');
    }
    buffer.write('  </div>\n');

    // Pager
    final pager = context['pager'] as Map<String, dynamic>? ?? const {};
    final prevHref = pager['prev_href'] != null ? htmlEscape(pager['prev_href'].toString()) : null;
    final nextHref = pager['next_href'] != null ? htmlEscape(pager['next_href'].toString()) : null;
    final pageNum = pager['page'] ?? 1;
    final totalPages = pager['total_pages'] ?? 1;
    final total = pager['total'] ?? 0;
    final exportQuery = htmlEscape(context['export_query']?.toString() ?? '');

    buffer.write('  <div>\n');
    if (prevHref != null) {
      buffer.write('    <a href="$prevHref">Previous</a>\n');
    }
    buffer.write('    Page $pageNum of $totalPages. Total: $total.\n');
    if (nextHref != null) {
      buffer.write('    <a href="$nextHref">Next</a>\n');
    }
    buffer.write('    <a href="export-csv/$exportQuery" style="margin-left: 1rem;">Export CSV</a>\n');
    buffer.write('  </div>\n');

    buffer.write('</form>\n');

    final fullContext = Map<String, dynamic>.from(context);
    fullContext['body'] = SafeHtml(buffer.toString());
    return const BaseTemplate().render(fullContext);
  }
}

/// Edit/Add Form HTML template.
class EditFormTemplate implements AdminTemplate {
  /// Creates an [EditFormTemplate] instance.
  const EditFormTemplate();

  @override
  String render(Map<String, dynamic> context) {
    final buffer = StringBuffer();
    final csrfToken = htmlEscape(context['csrf_token']?.toString() ?? '');
    final isAdd = context['is_add'] == true;
    final hasChange = context['has_change_permission'] == true;
    final hasDelete = context['has_delete_permission'] == true;
    final rows = context['rows'] as List<dynamic>? ?? const [];
    final inlines = context['inlines'] as List<dynamic>? ?? const [];

    buffer.write('<form method="post">\n');
    buffer.write('  <input type="hidden" name="csrfmiddlewaretoken" value="$csrfToken">\n');

    String? currentSection;
    var inFieldset = false;

    for (final row in rows) {
      final section = row['section']?.toString();
      if (section != currentSection) {
        if (inFieldset) {
          buffer.write('  </fieldset>\n');
        }
        if (section != null) {
          buffer.write('  <fieldset><legend>${htmlEscape(section)}</legend>\n');
          inFieldset = true;
        } else {
          inFieldset = false;
        }
        currentSection = section;
      }

      final kind = row['kind']?.toString() ?? 'text';
      final name = htmlEscape(row['name']?.toString() ?? '');
      final value = htmlEscape(row['value']?.toString() ?? '');
      final checked = row['checked'] == true;
      final error = row['error'] != null ? htmlEscape(row['error'].toString()) : null;
      final lookupHref = row['lookup_href'] != null ? htmlEscape(row['lookup_href'].toString()) : null;

      buffer.write('  <div class="form-row">\n');
      if (kind == 'readonly') {
        buffer.write('    <label>$name (readonly):</label> <span>$value</span>\n');
      } else if (kind == 'checkbox') {
        final checkedAttr = checked ? ' checked' : '';
        buffer.write('    <label for="id_$name"><input type="checkbox" name="$name" id="id_$name"$checkedAttr> $name</label>\n');
      } else if (kind == 'number') {
        buffer.write('    <label for="id_$name">$name</label>\n');
        buffer.write('    <input type="number" name="$name" id="id_$name" value="$value">\n');
        if (lookupHref != null) {
          buffer.write('    <a href="$lookupHref">Look up</a>\n');
        }
      } else {
        buffer.write('    <label for="id_$name">$name</label>\n');
        buffer.write('    <input type="text" name="$name" id="id_$name" value="$value">\n');
        if (lookupHref != null) {
          buffer.write('    <a href="$lookupHref">Look up</a>\n');
        }
      }

      if (error != null) {
        buffer.write('    <div class="form-error">$error</div>\n');
      }
      buffer.write('  </div>\n');
    }

    if (inFieldset) {
      buffer.write('  </fieldset>\n');
    }

    if (inlines.isNotEmpty) {
      for (final inline in inlines) {
        final structName = htmlEscape(inline['struct_name']?.toString() ?? '');
        final fields = inline['fields'] as List<dynamic>? ?? const [];
        final inlineRows = inline['rows'] as List<dynamic>? ?? const [];

        buffer.write('  <h2>$structName</h2>\n');
        buffer.write('  <table>\n    <thead>\n      <tr>\n');
        for (final col in fields) {
          buffer.write('        <th>${htmlEscape(col.toString())}</th>\n');
        }
        buffer.write('      </tr>\n    </thead>\n    <tbody>\n');
        for (final r in inlineRows) {
          buffer.write('      <tr>\n');
          final vals = r['values'] as List<dynamic>? ?? const [];
          for (final val in vals) {
            buffer.write('        <td>${htmlEscape(val.toString())}</td>\n');
          }
          buffer.write('      </tr>\n');
        }
        buffer.write('    </tbody>\n  </table>\n');
      }
    }

    buffer.write('  <div class="actions-bar">\n');
    if (hasChange) {
      buffer.write('    <input type="submit" value="Submit">\n');
    }
    if (!isAdd && hasDelete) {
      buffer.write('    <a href="../delete/" style="margin-left: 1rem; color: #dc2626;">Delete</a>\n');
    }
    buffer.write('  </div>\n');
    buffer.write('</form>\n');

    final fullContext = Map<String, dynamic>.from(context);
    fullContext['body'] = SafeHtml(buffer.toString());
    return const BaseTemplate().render(fullContext);
  }
}

/// Delete Confirmation HTML template.
class DeleteConfirmTemplate implements AdminTemplate {
  /// Creates a [DeleteConfirmTemplate] instance.
  const DeleteConfirmTemplate();

  @override
  String render(Map<String, dynamic> context) {
    final buffer = StringBuffer();
    final fields = context['fields'] as List<dynamic>? ?? const [];
    final related = context['related'] as List<dynamic>? ?? const [];
    final csrfToken = htmlEscape(context['csrf_token']?.toString() ?? '');

    buffer.write('<p>Are you sure you want to delete the following object?</p>\n');
    buffer.write('<div>\n');
    for (final f in fields) {
      final name = htmlEscape(f['name']?.toString() ?? '');
      final value = htmlEscape(f['value']?.toString() ?? '');
      buffer.write('  <div><strong>$name:</strong> $value</div>\n');
    }
    buffer.write('</div>\n');

    if (related.isNotEmpty) {
      buffer.write('<h3>Related Objects that will be affected:</h3>\n<ul>\n');
      void renderRelated(List<dynamic> items) {
        for (final r in items) {
          final structName = htmlEscape(r['struct_name']?.toString() ?? '');
          final tableName = htmlEscape(r['table_name']?.toString() ?? '');
          final count = r['count']?.toString() ?? '0';
          final onDelete = htmlEscape(r['on_delete']?.toString() ?? '');
          buffer.write('  <li>$structName (table: $tableName, count: $count, on_delete: $onDelete)');
          final nested = r['nested'] as List<dynamic>? ?? const [];
          if (nested.isNotEmpty) {
            buffer.write('\n    <ul>\n');
            renderRelated(nested);
            buffer.write('    </ul>\n  ');
          }
          buffer.write('</li>\n');
        }
      }
      renderRelated(related);
      buffer.write('</ul>\n');
    }

    buffer.write('<form method="post">\n');
    buffer.write('  <input type="hidden" name="csrfmiddlewaretoken" value="$csrfToken">\n');
    buffer.write('  <input type="submit" value="Confirm Delete" class="btn-danger">\n');
    buffer.write('  <a href="../change/" style="margin-left: 1rem;">Cancel</a>\n');
    buffer.write('</form>\n');

    final fullContext = Map<String, dynamic>.from(context);
    fullContext['body'] = SafeHtml(buffer.toString());
    return const BaseTemplate().render(fullContext);
  }
}

/// Bulk Delete Confirmation HTML template.
class BulkDeleteConfirmTemplate implements AdminTemplate {
  /// Creates a [BulkDeleteConfirmTemplate] instance.
  const BulkDeleteConfirmTemplate();


  @override
  String render(Map<String, dynamic> context) {
    final buffer = StringBuffer();
    final count = context['count'] ?? 0;
    final items = context['items'] as List<dynamic>? ?? const [];
    final pks = context['pks'] as List<dynamic>? ?? const [];
    final csrfToken = htmlEscape(context['csrf_token']?.toString() ?? '');

    buffer.write('<p>Are you sure you want to delete <strong>$count</strong> selected object(s)?</p>\n');
    buffer.write('<ul>\n');
    for (final item in items) {
      buffer.write('  <li>${htmlEscape(item.toString())}</li>\n');
    }
    buffer.write('</ul>\n');

    buffer.write('<form method="post">\n');
    buffer.write('  <input type="hidden" name="csrfmiddlewaretoken" value="$csrfToken">\n');
    for (final pk in pks) {
      buffer.write('  <input type="hidden" name="selected" value="${htmlEscape(pk.toString())}">\n');
    }
    buffer.write('  <input type="hidden" name="confirm" value="1">\n');
    buffer.write('  <input type="submit" value="Confirm Delete" class="btn-danger">\n');
    buffer.write('  <a href="./" style="margin-left: 1rem;">Cancel</a>\n');
    buffer.write('</form>\n');

    final fullContext = Map<String, dynamic>.from(context);
    fullContext['body'] = SafeHtml(buffer.toString());
    return const BaseTemplate().render(fullContext);
  }
}
