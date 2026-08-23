import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_server/bloom_server.dart';
import '../components/button_variants.dart';
import '../components/layout.dart';
import '../components/ui.dart';
import '../db.dart';
import '../models/repository.dart';

Future<BloomNode> adminDashboard(BloomRequest req) async {
  final counts = await fetchProductCountsByStatus();
  return adminShell(
    Div(children: [
      H1(className: 'text-h1', text: 'Overview'),
      P(className: 'text-sm text-[var(--text-muted)] mt-1', text: 'Product counts by status — TODO: Auth (Stage 2)'),
      Div(className: 'grid sm:grid-cols-3 gap-4 mt-6', children: [
        _metricCard('Published', counts['published'] ?? 0, 'check', 'var(--success)'),
        _metricCard('Draft', counts['draft'] ?? 0, 'draft', 'var(--warning)'),
        _metricCard('Archived', counts['archived'] ?? 0, 'archive', 'var(--n-500)'),
      ]),
      Div(className: 'mt-8 rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4', children: [
        H3(className: 'text-h3', text: 'Next steps'),
        P(className: 'text-sm text-[var(--text-muted)] mt-1', text: 'Stage 1: list and manage products. Stage 2 will add auth, audit log, and destructive-action guards.'),
        button(text: 'Go to products', href: '/admin/products', extraClassName: 'inline-flex mt-3'),
      ]),
    ]),
  );
}

BloomNode _metricCard(String label, int value, String icon, String color) {
  return Div(
    className: 'rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4 shadow-sm',
    children: [
      Div(className: 'flex items-center justify-between', children: [
        Span(className: 'text-xs uppercase tracking-widest text-[var(--text-muted)]', text: label),
        Span(className: 'w-8 h-8 rounded-md grid place-items-center', style: 'background: $color; color: white', children: [hugeIcon(icon, className: 'w-4 h-4')]),
      ]),
      Div(className: 'mt-3 text-3xl font-semibold tabular', style: 'font-family:var(--font-display); font-variant-numeric:tabular-nums', text: '$value'),
    ],
  );
}

Future<BloomNode> adminProducts(BloomRequest req) async {
  final cursor = req.queryParams['cursor'];
  final sort = req.queryParams['sort'] ?? 'newest';
  // Admin shows all statuses, includes draft/archived
  final data = await fetchProducts(cursor: cursor, limit: 24, sort: sort == 'price_asc' || sort == 'price_desc' ? sort : null, publishedOnly: false);
  // Manual sort for admin table sortable columns: if sort is title etc handle via query? For now use created_at default
  final rows = data.items.map((p) => tableRow([
        Div(children: [
          P(className: 'font-medium line-clamp-1', text: p.title),
          P(className: 'text-xs text-[var(--text-muted)]', text: p.slug),
        ]),
        priceText(p.priceCents),
        Span(className: 'tabular', text: '${p.stock}'),
        statusPill(p.status),
        Link(href: '/admin/products/${p.id}', className: 'text-sm text-[var(--brand-600)] hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]', text: 'Edit'),
      ])).toList();

  return adminShell(
    Div(children: [
      Div(className: 'flex items-center justify-between gap-4', children: [
        H1(className: 'text-h1', text: 'Products'),
        button(text: 'New product', href: '/admin/products/new'),
      ]),
      Div(className: 'flex items-center gap-2 text-sm mt-3', children: [
        Span(className: 'text-[var(--text-muted)]', text: 'Sort:'),
        Link(href: '/admin/products?sort=newest', className: 'px-2 py-1 rounded-md border border-[var(--border)] ${sort=='newest'?'bg-[var(--brand-600)] text-white border-transparent':''}', text: 'Newest'),
        Link(href: '/admin/products?sort=price_asc', className: 'px-2 py-1 rounded-md border border-[var(--border)] ${sort=='price_asc'?'bg-[var(--brand-600)] text-white border-transparent':''}', text: 'Price ↑'),
        Link(href: '/admin/products?sort=price_desc', className: 'px-2 py-1 rounded-md border border-[var(--border)] ${sort=='price_desc'?'bg-[var(--brand-600)] text-white border-transparent':''}', text: 'Price ↓'),
      ]),
      Div(className: 'mt-4', children: [
        adminTable(
          headers: ['Product', 'Price', 'Stock', 'Status', ''],
          rows: rows,
          empty: Div(className: 'py-12 text-center text-[var(--text-muted)]', text: 'No products'),
        ),
      ]),
      if (data.nextCursor != null)
        Div(className: 'mt-4 flex justify-end', children: [
          Link(href: '/admin/products?cursor=${Uri.encodeComponent(data.nextCursor!)}&sort=$sort', className: 'px-4 py-2 rounded-md bg-[var(--brand-600)] text-white text-sm', text: 'Next'),
        ])
      else
        Div(className: 'mt-4 text-sm text-[var(--text-muted)] text-right', text: 'End of results'),
    ]),
  );
}

Future<BloomNode> adminProductForm(BloomRequest req, {bool isNew = false}) async {
  ProductRef? prod;
  final idOrSlug = req.params['id'];
  if (!isNew && idOrSlug != null) {
    // id is uuid, fetch by id
    prod = await _fetchById(idOrSlug);
  }
  return adminShell(
    Div(children: [
      Link(href: '/admin/products', className: 'text-sm text-[var(--brand-600)] hover:underline', text: '← Back to products'),
      H1(className: 'text-h1 mt-2', text: isNew ? 'New product' : 'Edit product'),
      P(className: 'text-sm text-[var(--text-muted)]', text: isNew ? 'Create a new product — TODO: server mutation (Stage 2)' : 'Editing ${prod?.title ?? idOrSlug} — TODO: auth'),
      El('form',
        attrs: {'method': 'post', 'action': isNew ? '/admin/products' : '/admin/products/$idOrSlug'},
        className: 'mt-6 flex flex-col gap-4 max-w-[640px]',
        children: [
          _field('Title', 'title', prod?.title ?? '', required: true),
          _field('Slug', 'slug', prod?.slug ?? '', help: 'Stable, unique, used in URLs'),
          _field('Description', 'description', prod?.description ?? '', textarea: true),
          Div(className: 'grid grid-cols-2 gap-4', children: [
            _field('Price (cents)', 'price_cents', prod?.priceCents.toString() ?? '', help: 'Integer cents, e.g. 1999 = \$19.99'),
            _field('Stock', 'stock', prod?.stock.toString() ?? ''),
          ]),
          Div(className: 'grid grid-cols-2 gap-4', children: [
            _select('Status', 'status', prod?.status ?? 'draft', ['draft', 'published', 'archived']),
            _field('Currency', 'currency', prod?.currency ?? 'USD'),
          ]),
          Div(className: 'flex gap-3 mt-2', children: [
            button(text: isNew ? 'Create' : 'Save', attrs: const {'type': 'submit'}),
            button(text: 'Cancel', variant: ButtonVariant.secondary, href: '/admin/products'),
          ]),
        ],
      ),
    ]),
  );
}

BloomNode _field(String label, String name, String value, {bool required = false, bool textarea = false, String? help}) {
  final id = 'f-$name';
  return Div(className: 'flex flex-col gap-1.5', children: [
    El('label', attrs: {'for': id}, className: 'text-label', text: label),
    if (textarea)
      El('textarea', attrs: {'id': id, 'name': name, if (required) 'required': '' , 'rows': '4', 'aria-describedby': help != null ? '$id-help' : ''}, className: 'w-full px-3 py-2 rounded-[6px] border border-[var(--border)] bg-[var(--bg)] text-sm focus:outline-none focus:ring-2 focus:ring-[var(--brand-600)]', text: value)
    else
      El('input', attrs: {'id': id, 'name': name, 'value': value, if (required) 'required': '', 'aria-describedby': help != null ? '$id-help' : ''}, className: 'w-full px-3 py-2 rounded-[6px] border border-[var(--border)] bg-[var(--bg)] text-sm focus:outline-none focus:ring-2 focus:ring-[var(--brand-600)]'),
    if (help != null) P(attrs: {'id': '$id-help'}, className: 'text-xs text-[var(--text-muted)]', text: help),
  ]);
}

BloomNode _select(String label, String name, String value, List<String> opts) {
  final id = 'f-$name';
  return Div(className: 'flex flex-col gap-1.5', children: [
    El('label', attrs: {'for': id}, className: 'text-label', text: label),
    El('select', attrs: {'id': id, 'name': name}, className: 'w-full px-3 py-2 rounded-[6px] border border-[var(--border)] bg-[var(--bg)] text-sm focus:outline-none focus:ring-2 focus:ring-[var(--brand-600)]', children: opts.map((o) => El('option', attrs: {'value': o, if (o==value) 'selected': ''}, text: o)).toList()),
  ]);
}

class ProductRef {
  final String title; final String slug; final String description; final int priceCents; final int stock; final String status; final String currency;
  ProductRef({required this.title, required this.slug, required this.description, required this.priceCents, required this.stock, required this.status, required this.currency});
}

Future<ProductRef?> _fetchById(String id) async {
  // minimal fetch by id
  final db = await getDb();
  final row = await db.fetchOptional('SELECT title, slug, description, price_cents, stock, status, currency FROM products WHERE id = \$1', [id]);
  if (row == null) return null;
  return ProductRef(
    title: row.tryStringByName('title') ?? '',
    slug: row.tryStringByName('slug') ?? '',
    description: row.tryStringByName('description') ?? '',
    priceCents: row.tryIntByName('price_cents') ?? 0,
    stock: row.tryIntByName('stock') ?? 0,
    status: row.tryStringByName('status') ?? 'draft',
    currency: row.tryStringByName('currency') ?? 'USD',
  );
}


