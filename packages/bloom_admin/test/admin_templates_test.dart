import 'package:test/test.dart';
import 'package:bloom_admin/bloom_admin.dart';

void main() {
  group('BloomSiteBranding & Bloom Console Defaults', () {
    test('default branding uses Bloom Console identity', () {
      const branding = BloomSiteBranding();
      expect(branding.siteHeader, equals('Bloom Console'));
      expect(branding.siteTitle, equals('Bloom Console'));
      expect(branding.logoUrl, isNull);
      expect(branding.accentColor, isNull);
    });

    test('branding overrides are preserved through copyWith and BloomAdminSite',
        () {
      final site = BloomAdminSite()
          .withSiteHeader('Custom Enterprise Admin')
          .withSiteTitle('Acme Portal')
          .withLogoUrl('https://example.com/brand.svg')
          .withAccentColor('#10b981');

      expect(site.branding.siteHeader, equals('Custom Enterprise Admin'));
      expect(site.branding.siteTitle, equals('Acme Portal'));
      expect(site.branding.logoUrl, equals('https://example.com/brand.svg'));
      expect(site.branding.accentColor, equals('#10b981'));
    });
  });

  group('BaseTemplate & Shell Layout', () {
    test(
        'renders default Bloom Console title and inline Bloom SVG mark without scripts',
        () {
      const template = BaseTemplate();
      final html = template.render({
        'body': SafeHtml('<p>Dashboard content</p>'),
      });

      // Title & Header
      expect(html, contains('<title>Bloom Console</title>'));
      expect(html, contains('Bloom Console'));

      // Inline SVG Bloom mark
      expect(html, contains('<svg'));
      expect(html, contains('class="site-logo bloom-mark"'));
      expect(
          html, contains('11.5228')); // signature Bloom SVG curve coordinates
      expect(html, isNot(contains('<img')));

      // Server-rendered and JS-free
      expect(html, isNot(contains('<script')));

      // Modern Bloom CSS design tokens
      expect(html, contains('--bloom-bg: #09090B;'));
      expect(html, contains('--bloom-surface: #14141A;'));
      expect(html, contains('--bloom-border: #1E1E24;'));
      expect(html, contains('--bloom-accent: #6366F1;'));

      // Body content passed through safely
      expect(html, contains('<p>Dashboard content</p>'));
    });

    test(
        'renders custom logoUrl image when overridden and omits inline SVG mark',
        () {
      const template = BaseTemplate();
      final html = template.render({
        'site_header': 'Custom Dashboard',
        'site_title': 'Custom Title',
        'logo_url': 'https://example.com/custom-logo.png',
        'body': SafeHtml('<div>Main View</div>'),
      });

      expect(html, contains('<title>Custom Title</title>'));
      expect(html, contains('Custom Dashboard'));
      expect(
          html,
          contains(
              '<img src="${htmlEscape('https://example.com/custom-logo.png')}" alt="" class="site-logo">'));
      expect(html, isNot(contains('bloom-mark')));
    });

    test('applies custom accentColor override via CSS variables', () {
      const template = BaseTemplate();
      final html = template.render({
        'accent_color': '#EC4899',
        'body': SafeHtml('<div>Accent View</div>'),
      });

      expect(html, contains('--bloom-accent: #EC4899;'));
      expect(html, contains('--accent: #EC4899;'));
    });
  });

  group('Console Views & Templates', () {
    test('IndexTemplate renders responsive model cards and dashboard sections',
        () {
      const template = IndexTemplate();
      final html = template.render({
        'site_header': 'Bloom Console',
        'models': [
          {
            'href': '/admin/auth/user/',
            'label': 'auth.User',
            'has_view_permission': true,
            'has_change_permission': true,
            'has_add_permission': true,
          },
          {
            'href': '/admin/blog/post/',
            'label': 'blog.Post',
            'has_view_permission': true,
            'has_change_permission': true,
            'has_add_permission': true,
          },
        ],
        'recent_actions': [
          {
            'action_time': '2026-08-31 12:00:00',
            'action_label': 'Added',
            'app_label': 'auth',
            'model_name': 'User',
            'object_repr': 'admin@bloom.dev',
          }
        ],
      });

      expect(html, contains('auth.User'));
      expect(html, contains('blog.Post'));
      expect(html, contains(htmlEscape('/admin/auth/user/')));
      expect(html, contains(htmlEscape('/admin/auth/user/add/')));
      expect(html, contains('Recent actions'));
      expect(html, contains('admin@bloom.dev'));
      expect(html, contains('console-grid'));
      expect(html, contains('console-card'));
    });

    test(
        'ChangelistTemplate renders responsive data grid, filters, search, and actions',
        () {
      const template = ChangelistTemplate();
      final html = template.render({
        'model_name': 'Product',
        'site_header': 'Bloom Console',
        'csrf_token': 'test_csrf_token_123',
        'has_add_permission': true,
        'has_delete_permission': true,
        'has_change_permission': true,
        'show_save_button': true,
        'search': {
          'visible': true,
          'q_value': 'wireless',
          'hidden_inputs': [
            {'name': 'o', 'value': '-price'}
          ],
        },
        'list_filter_blocks': [
          {
            'field': 'is_active',
            'all_href': '?o=-price',
            'yes_href': '?o=-price&is_active=true',
            'no_href': '?o=-price&is_active=false',
          }
        ],
        'header_cells': [
          {'href': '?o=id', 'label': 'id'},
          {'href': '?o=name', 'label': 'name'},
          {'href': '?o=price', 'label': 'price'},
        ],
        'rows': [
          {
            'pk': '42',
            'cells': [
              {'kind': 'pk_link', 'value': '42', 'field_name': 'id'},
              {
                'kind': 'editable',
                'value': 'Wireless Keyboard',
                'field_name': 'name'
              },
              {'kind': 'plain', 'value': '99.99', 'field_name': 'price'},
            ],
          }
        ],
        'actions': [
          {'name': 'publish', 'label': 'Publish selected'},
        ],
        'pager': {
          'page': 1,
          'total_pages': 5,
          'total': 48,
          'prev_href': null,
          'next_href': '?page=2',
        },
        'export_query': '?o=-price',
      });

      expect(html, contains('Product'));
      expect(html, contains('test_csrf_token_123'));
      expect(html, contains('Wireless Keyboard'));
      expect(html, contains('action-toggle'));
      expect(html, contains('Publish selected'));
      expect(html, contains('Export CSV'));
      expect(html, contains('Page 1 of 5'));
      expect(html, contains('console-table'));
    });

    test('EditFormTemplate renders form fields, fieldsets, and actions', () {
      const template = EditFormTemplate();
      final html = template.render({
        'site_header': 'Bloom Console',
        'csrf_token': 'test_csrf_token_456',
        'is_add': false,
        'has_change_permission': true,
        'has_delete_permission': true,
        'rows': [
          {
            'kind': 'readonly',
            'name': 'id',
            'value': '101',
            'checked': false,
            'error': null,
            'section': 'Metadata',
            'lookup_href': null,
          },
          {
            'kind': 'text',
            'name': 'title',
            'value': 'Release 1.0',
            'checked': false,
            'error': 'Title is required',
            'section': 'General',
            'lookup_href': null,
          },
          {
            'kind': 'checkbox',
            'name': 'published',
            'value': 'true',
            'checked': true,
            'error': null,
            'section': 'General',
            'lookup_href': null,
          }
        ],
        'inlines': [
          {
            'struct_name': 'Comment',
            'fields': ['id', 'author', 'content'],
            'rows': [
              {
                'values': ['1', 'Alice', 'Great job!'],
              }
            ],
          }
        ],
      });

      expect(html, contains('Metadata'));
      expect(html, contains('General'));
      expect(html, contains('id (readonly)'));
      expect(html, contains('101'));
      expect(html, contains('Release 1.0'));
      expect(html, contains('Title is required'));
      expect(html, contains('Comment'));
      expect(html, contains('Alice'));
      expect(html, contains('Delete'));
      expect(html, contains('test_csrf_token_456'));
    });

    test(
        'DeleteConfirmTemplate and BulkDeleteConfirmTemplate render confirmation cards',
        () {
      const deleteTpl = DeleteConfirmTemplate();
      final deleteHtml = deleteTpl.render({
        'csrf_token': 'del_token_1',
        'fields': [
          {'name': 'id', 'value': '7'},
          {'name': 'name', 'value': 'Sample Project'},
        ],
        'related': [
          {
            'struct_name': 'Task',
            'table_name': 'tasks',
            'count': 12,
            'on_delete': 'cascade',
            'nested': <dynamic>[],
          }
        ],
      });

      expect(deleteHtml, contains('Sample Project'));
      expect(deleteHtml,
          contains('Task (table: tasks, count: 12, on_delete: cascade)'));
      expect(deleteHtml, contains('Confirm Delete'));
      expect(deleteHtml, contains('btn-danger'));

      const bulkTpl = BulkDeleteConfirmTemplate();
      final bulkHtml = bulkTpl.render({
        'csrf_token': 'del_token_2',
        'count': 3,
        'items': ['Project 1', 'Project 2', 'Project 3'],
        'pks': [1, 2, 3],
      });

      expect(bulkHtml, contains('<strong>3</strong>'));
      expect(bulkHtml, contains('Project 2'));
      expect(bulkHtml, contains('Confirm Delete'));
    });
  });
}
