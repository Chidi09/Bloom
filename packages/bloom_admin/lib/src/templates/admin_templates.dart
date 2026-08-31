import 'template_engine.dart';

/// Base layout HTML template for `bloom_admin`.
class BaseTemplate implements AdminTemplate {
  /// Creates a [BaseTemplate] instance.
  const BaseTemplate();

  @override
  String render(Map<String, dynamic> context) {
    final title =
        htmlEscape(context['site_title']?.toString() ?? 'Bloom Console');
    final siteHeader =
        htmlEscape(context['site_header']?.toString() ?? 'Bloom Console');
    final accentColor = context['accent_color'] != null
        ? htmlEscape(context['accent_color'].toString())
        : null;
    final logoUrl = context['logo_url']?.toString();
    final bodyContent = context['body'] is SafeHtml
        ? (context['body'] as SafeHtml).rawHtml
        : htmlEscape(context['body']?.toString() ?? '');

    final accentStyle = accentColor != null
        ? '<style>:root { --bloom-accent: $accentColor; --accent: $accentColor; }</style>'
        : '';
    final logoTag = logoUrl != null && logoUrl.isNotEmpty
        ? '<img src="${htmlEscape(logoUrl)}" alt="" class="site-logo">'
        : '<svg class="site-logo bloom-mark" width="24" height="24" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M16 6C16 11.5228 11.5228 16 6 16C11.5228 16 16 20.4772 16 26C16 20.4772 20.4772 16 26 16C20.4772 16 16 11.5228 16 6Z" fill="url(#bloomMarkGrad)"/><defs><linearGradient id="bloomMarkGrad" x1="6" y1="6" x2="26" y2="26" gradientUnits="userSpaceOnUse"><stop stop-color="#818CF8"/><stop offset="0.5" stop-color="#6366F1"/><stop offset="1" stop-color="#EC4899"/></linearGradient></defs></svg>';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<style>
:root {
  --bloom-bg: #09090B;
  --bloom-surface: #14141A;
  --bloom-surface-elevated: #1C1C24;
  --bloom-surface-hover: #22222D;
  --bloom-border: #1E1E24;
  --bloom-border-subtle: #27272A;
  --bloom-text: #F4F4F5;
  --bloom-text-muted: #A1A1AA;
  --bloom-text-dim: #71717A;
  --bloom-accent: #6366F1;
  --bloom-accent-hover: #4F46E5;
  --bloom-accent-subtle: rgba(99, 102, 241, 0.12);
  --bloom-danger: #EF4444;
  --bloom-danger-hover: #DC2626;
  --bloom-danger-subtle: rgba(239, 68, 68, 0.12);
  --bloom-success: #10B981;
  --bloom-success-subtle: rgba(16, 185, 129, 0.12);
  --bloom-warning: #F59E0B;
  --bloom-warning-subtle: rgba(245, 158, 11, 0.12);
  --bloom-radius: 8px;
  --bloom-radius-sm: 6px;
  --bloom-font: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Ubuntu, sans-serif;
  --bloom-font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;

  --bg: var(--bloom-bg);
  --fg: var(--bloom-text);
  --muted: var(--bloom-text-muted);
  --accent: var(--bloom-accent);
  --border: var(--bloom-border);
  --input-bg: var(--bloom-surface);
  --row-alt: var(--bloom-surface);
}
* { box-sizing: border-box; }
body {
  background: var(--bloom-bg);
  color: var(--bloom-text);
  font-family: var(--bloom-font);
  margin: 0;
  padding: 0;
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
  min-height: 100vh;
}
a { color: var(--bloom-accent); text-decoration: none; transition: color 0.15s ease; }
a:hover { color: var(--bloom-text); text-decoration: underline; }
.console-shell {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}
.console-header {
  background: var(--bloom-surface);
  border-bottom: 1px solid var(--bloom-border);
  padding: 1rem 1.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}
.console-brand {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--bloom-text);
  letter-spacing: -0.01em;
}
.site-logo {
  height: 1.5rem;
  width: 1.5rem;
  flex-shrink: 0;
  vertical-align: middle;
}
.console-container {
  max-width: 1200px;
  width: 100%;
  margin: 0 auto;
  padding: 1.5rem;
  flex: 1;
}
.console-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
  margin: 1rem 0;
}
.console-card {
  background: var(--bloom-surface);
  border: 1px solid var(--bloom-border);
  border-radius: var(--bloom-radius);
  padding: 1.25rem;
  transition: border-color 0.15s ease, background 0.15s ease;
}
.console-card:hover {
  border-color: var(--bloom-border-subtle);
  background: var(--bloom-surface-elevated);
}
.console-table-wrapper {
  background: var(--bloom-surface);
  border: 1px solid var(--bloom-border);
  border-radius: var(--bloom-radius);
  overflow-x: auto;
  margin: 1rem 0;
}
table.console-table, table {
  border-collapse: collapse;
  width: 100%;
  text-align: left;
  font-size: 0.875rem;
}
th, td {
  border-bottom: 1px solid var(--bloom-border);
  padding: 0.75rem 1rem;
  vertical-align: middle;
}
th {
  background: var(--bloom-surface);
  color: var(--bloom-text-muted);
  font-weight: 600;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
tbody tr {
  transition: background 0.1s ease;
}
tbody tr:hover {
  background: var(--bloom-surface-hover);
}
tbody tr:last-child td {
  border-bottom: none;
}
input, button, select {
  font: inherit;
  color: inherit;
}
input[type="text"], input[type="number"], input[type="password"], input[type="email"], select {
  background: var(--bloom-bg);
  border: 1px solid var(--bloom-border);
  border-radius: var(--bloom-radius-sm);
  padding: 0.45rem 0.75rem;
  color: var(--bloom-text);
  font-size: 0.875rem;
  outline: none;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
input[type="text"]:focus, input[type="number"]:focus, input[type="password"]:focus, input[type="email"]:focus, select:focus {
  border-color: var(--bloom-accent);
  box-shadow: 0 0 0 1px var(--bloom-accent);
}
button, input[type="submit"], .console-btn {
  background: var(--bloom-accent);
  color: #ffffff;
  border: 1px solid transparent;
  border-radius: var(--bloom-radius-sm);
  padding: 0.45rem 0.9rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  text-decoration: none;
  transition: background 0.15s ease, opacity 0.15s ease;
}
button:hover, input[type="submit"]:hover, .console-btn:hover {
  background: var(--bloom-accent-hover);
  text-decoration: none;
}
.btn-danger {
  background: var(--bloom-danger) !important;
}
.btn-danger:hover {
  background: var(--bloom-danger-hover) !important;
}
.btn-secondary, .btn-outline {
  background: transparent !important;
  border: 1px solid var(--bloom-border) !important;
  color: var(--bloom-text) !important;
}
.btn-secondary:hover, .btn-outline:hover {
  background: var(--bloom-surface-hover) !important;
  border-color: var(--bloom-border-subtle) !important;
}
.actions-bar {
  margin: 1rem 0;
  display: flex;
  gap: 0.75rem;
  align-items: center;
  flex-wrap: wrap;
}
.filter-bar {
  margin: 0.75rem 0;
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
}
.filter-item {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.8125rem;
  color: var(--bloom-text-muted);
  background: var(--bloom-surface);
  border: 1px solid var(--bloom-border);
  padding: 0.3rem 0.6rem;
  border-radius: var(--bloom-radius-sm);
}
.search-bar {
  margin: 1rem 0;
}
.search-bar form {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}
.date-hierarchy {
  margin: 0.5rem 0;
  color: var(--bloom-text-muted);
  font-size: 0.875rem;
}
h1, .console-brand h1 {
  font-size: 1.125rem;
  font-weight: 600;
  margin: 0;
  color: var(--bloom-text);
  letter-spacing: -0.01em;
  display: inline-flex;
  align-items: center;
  gap: 0.75rem;
}
h2 {
  font-size: 1.1rem;
  font-weight: 600;
  margin: 1.5rem 0 0.75rem;
  color: var(--bloom-text);
}
h3 {
  font-size: 0.95rem;
  font-weight: 600;
  margin: 1rem 0 0.5rem;
  color: var(--bloom-text);
}
.form-row {
  margin-bottom: 1.25rem;
}
.form-row label {
  display: block;
  font-weight: 500;
  font-size: 0.875rem;
  margin-bottom: 0.4rem;
  color: var(--bloom-text);
}
.form-error {
  color: var(--bloom-danger);
  font-size: 0.8125rem;
  margin-top: 0.35rem;
}
fieldset {
  border: 1px solid var(--bloom-border);
  border-radius: var(--bloom-radius);
  margin-bottom: 1.5rem;
  padding: 1.25rem;
  background: var(--bloom-surface);
}
legend {
  font-weight: 600;
  font-size: 0.875rem;
  padding: 0 0.5rem;
  color: var(--bloom-text);
}
.console-pagination {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 1rem;
  font-size: 0.875rem;
  color: var(--bloom-text-muted);
  flex-wrap: wrap;
  gap: 0.75rem;
}
@media (max-width: 640px) {
  .console-container { padding: 1rem; }
  .console-header { padding: 0.75rem 1rem; }
  .actions-bar { flex-direction: column; align-items: stretch; }
  .actions-bar select, .actions-bar button, .actions-bar a { width: 100%; text-align: center; }
}
</style>
$accentStyle
</head>
<body>
<div class="console-shell">
  <header class="console-header">
    <div class="console-brand">
      $logoTag
      <h1>$siteHeader</h1>
    </div>
  </header>
  <main class="console-container">
    $bodyContent
  </main>
</div>
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
    final recentActions =
        context['recent_actions'] as List<dynamic>? ?? const [];

    final buffer = StringBuffer();
    buffer.write('<div class="console-grid">\n');
    for (final m in models) {
      final rawHref = m['href']?.toString() ?? '';
      final href = htmlEscape(rawHref);
      final label = htmlEscape(m['label']?.toString() ?? '');
      final hasView = m['has_view_permission'] == true;
      final hasChange = m['has_change_permission'] == true;
      final hasAdd = m['has_add_permission'] == true;

      if (hasView || hasChange || hasAdd) {
        buffer.write('  <div class="console-card">\n');
        buffer.write(
            '    <div style="display: flex; justify-content: space-between; align-items: center;">\n');
        buffer.write(
            '      <a href="$href" style="font-weight: 600; font-size: 1rem;">$label</a>\n');
        if (hasAdd) {
          final rawAdd =
              rawHref.endsWith('/') ? '${rawHref}add/' : '$rawHref/add/';
          final addHref = htmlEscape(rawAdd);
          buffer.write(
              '      <a href="$addHref" class="console-btn btn-secondary" style="font-size: 0.75rem; padding: 0.25rem 0.5rem;">+ Add</a>\n');
        }
        buffer.write('    </div>\n');
        buffer.write('  </div>\n');
      }
    }
    buffer.write('</div>\n');

    if (recentActions.isNotEmpty) {
      buffer.write('<div class="console-card" style="margin-top: 2rem;">\n');
      buffer.write('  <h2 style="margin-top: 0;">Recent actions</h2>\n');
      buffer.write('  <ul style="list-style: none; padding: 0; margin: 0;">\n');
      for (final a in recentActions) {
        final time = htmlEscape(a['action_time']?.toString() ?? '');
        final label = htmlEscape(a['action_label']?.toString() ?? '');
        final appLabel = htmlEscape(a['app_label']?.toString() ?? '');
        final modelName = htmlEscape(a['model_name']?.toString() ?? '');
        final repr = htmlEscape(a['object_repr']?.toString() ?? '');
        buffer.write(
            '    <li style="padding: 0.5rem 0; border-bottom: 1px solid var(--bloom-border); display: flex; gap: 0.5rem; font-size: 0.875rem;">\n');
        buffer.write(
            '      <span style="color: var(--bloom-text-dim);">$time</span>\n');
        buffer.write('      <span style="font-weight: 500;">$label</span>\n');
        buffer.write('      <span>$appLabel.$modelName:</span>\n');
        buffer.write(
            '      <span style="color: var(--bloom-text-muted);">$repr</span>\n');
        buffer.write('    </li>\n');
      }
      buffer.write('  </ul>\n');
      buffer.write('</div>\n');
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

    buffer.write(
        '<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; flex-wrap: wrap; gap: 0.5rem;">\n');
    buffer.write('  <h2 style="margin: 0;">$modelName</h2>\n');
    if (hasAdd) {
      buffer
          .write('  <a href="add/" class="console-btn">+ Add $modelName</a>\n');
    }
    buffer.write('</div>\n');

    // Search bar
    final search = context['search'] as Map<String, dynamic>?;
    if (search != null && search['visible'] == true) {
      buffer.write('<div class="search-bar">\n<form method="get">\n');
      final hiddenInputs =
          search['hidden_inputs'] as List<dynamic>? ?? const [];
      for (final h in hiddenInputs) {
        final hName = htmlEscape(h['name']?.toString() ?? '');
        final hVal = htmlEscape(h['value']?.toString() ?? '');
        buffer.write('  <input type="hidden" name="$hName" value="$hVal">\n');
      }
      final qVal = htmlEscape(search['q_value']?.toString() ?? '');
      buffer.write(
          '  <input type="text" name="q" value="$qVal" placeholder="Search $modelName...">\n');
      buffer.write('  <input type="submit" value="Search">\n');
      buffer.write('</form>\n</div>\n');
    }

    // List filters
    final filterBlocks =
        context['list_filter_blocks'] as List<dynamic>? ?? const [];
    if (filterBlocks.isNotEmpty) {
      buffer.write('<div class="filter-bar">\n');
      for (final f in filterBlocks) {
        final field = htmlEscape(f['field']?.toString() ?? '');
        final allHref = htmlEscape(f['all_href']?.toString() ?? '');
        final yesHref = htmlEscape(f['yes_href']?.toString() ?? '');
        final noHref = htmlEscape(f['no_href']?.toString() ?? '');
        buffer.write(
            '  <div class="filter-item">Filter by $field: <a href="$allHref">All</a> | <a href="$yesHref">Yes</a> | <a href="$noHref">No</a></div>\n');
      }
      buffer.write('</div>\n');
    }

    // Main changelist form
    buffer.write('<form method="post" action="bulk-delete/">\n');
    buffer.write(
        '  <input type="hidden" name="csrfmiddlewaretoken" value="$csrfToken">\n');
    buffer.write('  <div class="console-table-wrapper">\n');
    buffer.write(
        '  <table class="console-table">\n    <thead>\n      <tr>\n        <th style="width: 40px;"><input type="checkbox" id="action-toggle" onclick="document.querySelectorAll(\'tbody input[type=checkbox]\').forEach(c=>c.checked=this.checked)"></th>\n');

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
      buffer.write(
          '      <tr>\n        <td><input type="checkbox" name="selected" value="$pk"></td>\n');

      for (final cell in cells) {
        final kind = cell['kind']?.toString() ?? 'plain';
        final val = htmlEscape(cell['value']?.toString() ?? '');
        final fieldName = htmlEscape(cell['field_name']?.toString() ?? '');

        if (kind == 'pk_link') {
          buffer.write(
              '        <td><a href="$pk/change/" style="font-weight: 500;">$val</a></td>\n');
        } else if (kind == 'editable') {
          buffer.write(
              '        <td><input type="text" name="edit-$pk-$fieldName" value="$val"></td>\n');
        } else {
          buffer.write('        <td>$val</td>\n');
        }
      }
      buffer.write('      </tr>\n');
    }
    buffer.write('    </tbody>\n  </table>\n');
    buffer.write('  </div>\n');

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
      buffer.write(
          '    <button type="submit" formaction="bulk-action/">Go</button>\n');
    }
    if (hasDelete) {
      buffer.write(
          '    <button type="submit" formaction="bulk-delete/" class="btn-danger">Delete selected</button>\n');
    }
    if (hasChange && showSave) {
      buffer.write(
          '    <button type="submit" formaction="save-changelist/">Save</button>\n');
    }
    buffer.write('  </div>\n');

    // Pager
    final pager = context['pager'] as Map<String, dynamic>? ?? const {};
    final prevHref = pager['prev_href'] != null
        ? htmlEscape(pager['prev_href'].toString())
        : null;
    final nextHref = pager['next_href'] != null
        ? htmlEscape(pager['next_href'].toString())
        : null;
    final pageNum = pager['page'] ?? 1;
    final totalPages = pager['total_pages'] ?? 1;
    final total = pager['total'] ?? 0;
    final exportQuery = htmlEscape(context['export_query']?.toString() ?? '');

    buffer.write('  <div class="console-pagination">\n');
    buffer.write('    <div>\n');
    if (prevHref != null) {
      buffer.write(
          '      <a href="$prevHref" class="console-btn btn-secondary" style="margin-right: 0.5rem; padding: 0.25rem 0.6rem;">Previous</a>\n');
    }
    buffer.write('      Page $pageNum of $totalPages. Total: $total.\n');
    if (nextHref != null) {
      buffer.write(
          '      <a href="$nextHref" class="console-btn btn-secondary" style="margin-left: 0.5rem; padding: 0.25rem 0.6rem;">Next</a>\n');
    }
    buffer.write('    </div>\n');
    buffer.write(
        '    <a href="export-csv/$exportQuery" class="console-btn btn-secondary" style="padding: 0.25rem 0.6rem;">Export CSV</a>\n');
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

    buffer.write('<form method="post" class="console-card">\n');
    buffer.write(
        '  <input type="hidden" name="csrfmiddlewaretoken" value="$csrfToken">\n');

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
      final error =
          row['error'] != null ? htmlEscape(row['error'].toString()) : null;
      final lookupHref = row['lookup_href'] != null
          ? htmlEscape(row['lookup_href'].toString())
          : null;

      buffer.write('  <div class="form-row">\n');
      if (kind == 'readonly') {
        buffer.write(
            '    <label>$name (readonly):</label> <span style="font-family: var(--bloom-font-mono); color: var(--bloom-text-muted);">$value</span>\n');
      } else if (kind == 'checkbox') {
        final checkedAttr = checked ? ' checked' : '';
        buffer.write(
            '    <label for="id_$name"><input type="checkbox" name="$name" id="id_$name"$checkedAttr> $name</label>\n');
      } else if (kind == 'number') {
        buffer.write('    <label for="id_$name">$name</label>\n');
        buffer.write(
            '    <input type="number" name="$name" id="id_$name" value="$value">\n');
        if (lookupHref != null) {
          buffer.write(
              '    <a href="$lookupHref" style="margin-left: 0.5rem; font-size: 0.8125rem;">Look up</a>\n');
        }
      } else {
        buffer.write('    <label for="id_$name">$name</label>\n');
        buffer.write(
            '    <input type="text" name="$name" id="id_$name" value="$value">\n');
        if (lookupHref != null) {
          buffer.write(
              '    <a href="$lookupHref" style="margin-left: 0.5rem; font-size: 0.8125rem;">Look up</a>\n');
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
        buffer.write('  <div class="console-table-wrapper">\n');
        buffer.write(
            '  <table class="console-table">\n    <thead>\n      <tr>\n');
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
        buffer.write('  </div>\n');
      }
    }

    buffer.write('  <div class="actions-bar">\n');
    if (hasChange) {
      buffer.write('    <input type="submit" value="Submit">\n');
    }
    if (!isAdd && hasDelete) {
      buffer.write(
          '    <a href="../delete/" class="console-btn btn-danger" style="margin-left: 1rem;">Delete</a>\n');
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

    buffer.write('<div class="console-card">\n');
    buffer.write(
        '  <h2 style="margin-top: 0; color: var(--bloom-danger);">Confirm Deletion</h2>\n');
    buffer.write(
        '  <p>Are you sure you want to delete the following object?</p>\n');
    buffer.write(
        '  <div style="background: var(--bloom-bg); border: 1px solid var(--bloom-border); border-radius: var(--bloom-radius-sm); padding: 1rem; margin: 1rem 0;">\n');
    for (final f in fields) {
      final name = htmlEscape(f['name']?.toString() ?? '');
      final value = htmlEscape(f['value']?.toString() ?? '');
      buffer.write(
          '    <div style="margin-bottom: 0.25rem;"><strong>$name:</strong> <span style="color: var(--bloom-text-muted);">$value</span></div>\n');
    }
    buffer.write('  </div>\n');

    if (related.isNotEmpty) {
      buffer
          .write('  <h3>Related Objects that will be affected:</h3>\n  <ul>\n');
      void renderRelated(List<dynamic> items) {
        for (final r in items) {
          final structName = htmlEscape(r['struct_name']?.toString() ?? '');
          final tableName = htmlEscape(r['table_name']?.toString() ?? '');
          final count = r['count']?.toString() ?? '0';
          final onDelete = htmlEscape(r['on_delete']?.toString() ?? '');
          buffer.write(
              '    <li>$structName (table: $tableName, count: $count, on_delete: $onDelete)');
          final nested = r['nested'] as List<dynamic>? ?? const [];
          if (nested.isNotEmpty) {
            buffer.write('\n      <ul>\n');
            renderRelated(nested);
            buffer.write('      </ul>\n    ');
          }
          buffer.write('</li>\n');
        }
      }

      renderRelated(related);
      buffer.write('  </ul>\n');
    }

    buffer.write('  <form method="post" style="margin-top: 1.5rem;">\n');
    buffer.write(
        '    <input type="hidden" name="csrfmiddlewaretoken" value="$csrfToken">\n');
    buffer.write(
        '    <input type="submit" value="Confirm Delete" class="btn-danger">\n');
    buffer.write(
        '    <a href="../change/" class="console-btn btn-secondary" style="margin-left: 1rem;">Cancel</a>\n');
    buffer.write('  </form>\n');
    buffer.write('</div>\n');

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

    buffer.write('<div class="console-card">\n');
    buffer.write(
        '  <h2 style="margin-top: 0; color: var(--bloom-danger);">Confirm Bulk Deletion</h2>\n');
    buffer.write(
        '  <p>Are you sure you want to delete <strong>$count</strong> selected object(s)?</p>\n');
    buffer.write(
        '  <div style="background: var(--bloom-bg); border: 1px solid var(--bloom-border); border-radius: var(--bloom-radius-sm); padding: 1rem; margin: 1rem 0; max-height: 240px; overflow-y: auto;">\n');
    buffer.write('    <ul style="margin: 0; padding-left: 1.25rem;">\n');
    for (final item in items) {
      buffer.write('      <li>${htmlEscape(item.toString())}</li>\n');
    }
    buffer.write('    </ul>\n');
    buffer.write('  </div>\n');

    buffer.write('  <form method="post" style="margin-top: 1.5rem;">\n');
    buffer.write(
        '    <input type="hidden" name="csrfmiddlewaretoken" value="$csrfToken">\n');
    for (final pk in pks) {
      buffer.write(
          '    <input type="hidden" name="selected" value="${htmlEscape(pk.toString())}">\n');
    }
    buffer.write('    <input type="hidden" name="confirm" value="1">\n');
    buffer.write(
        '    <input type="submit" value="Confirm Delete" class="btn-danger">\n');
    buffer.write(
        '    <a href="./" class="console-btn btn-secondary" style="margin-left: 1rem;">Cancel</a>\n');
    buffer.write('  </form>\n');
    buffer.write('</div>\n');

    final fullContext = Map<String, dynamic>.from(context);
    fullContext['body'] = SafeHtml(buffer.toString());
    return const BaseTemplate().render(fullContext);
  }
}
