import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

class _ArchitectureTab {
  final String id;
  final String name;
  final String badge;
  final String icon;
  final String description;
  final String filename;
  final String code;
  final List<String> highlights;

  const _ArchitectureTab({
    required this.id,
    required this.name,
    required this.badge,
    required this.icon,
    required this.description,
    required this.filename,
    required this.code,
    required this.highlights,
  });
}

const _tabs = <_ArchitectureTab>[
  _ArchitectureTab(
    id: 'routing',
    name: 'File-System Routing',
    badge: 'AST_GENERATOR',
    icon: 'folder',
    description:
        'Next.js-style directory structure mapping directly to type-safe '
        'go_router definitions automatically on file save.',
    filename: 'lib/app/routes/products/[id].dart',
    code: '''// lib/app/routes/products/[id].dart
@RoutePage()
class ProductPage extends BloomPage {
  @PathParam('id')
  final String productId;

  ProductPage({required this.productId});

  @override
  Widget build(BuildContext context) {
    return Watch((_) => Text('Product ID: \$productId'));
  }
}''',
    highlights: [
      'Automatic URL parameter binding (@PathParam)',
      'Group routes with parentheses `(auth)/login.dart`',
      'Nested layout inheritance via `_layout.dart`',
    ],
  ),
  _ArchitectureTab(
    id: 'signals',
    name: 'Signals State API',
    badge: 'ZERO_SETSTATE',
    icon: 'refresh',
    description:
        'Fine-grained reactive signals tracking widget dependencies automatically. '
        'Zero setState, zero verbose Bloc streams.',
    filename: 'lib/controllers/cart_controller.dart',
    code: '''// lib/controllers/cart_controller.dart
class CartController extends BloomController {
  final items = signal<List<CartItem>>([]);

  late final totalPrice = computed(() =>
    items.value.fold(0.0, (sum, i) => sum + i.price)
  );

  void addItem(CartItem item) => items.value = [...items.value, item];
}''',
    highlights: [
      'Sub-millisecond dependency tracking at 60fps',
      'Computed signals auto-memoize derived state',
      'Rebuilds only the exact widget reading the signal',
    ],
  ),
  _ArchitectureTab(
    id: 'query',
    name: 'Bloom Query Engine',
    badge: 'SERVER_STATE',
    icon: 'zap',
    description:
        'Declarative data fetching, background revalidation, global memory '
        'cache, and optimistic mutation rollbacks.',
    filename: 'lib/views/product_card.dart',
    code: '''// Declarative query hook
final productQuery = useBloomQuery<Product>(
  key: 'product_\$id',
  fetcher: () => api.fetchProduct(id),
  staleTime: Duration(minutes: 5),
);

return productQuery.when(
  data: (p) => ProductCard(product: p),
  loading: () => SkeletonLoader(),
  error: (e) => ErrorNotice(e),
);''',
    highlights: [
      'Global in-memory cache with stale-while-revalidate',
      'Window focus & app resume revalidation',
      'Automatic optimistic UI updates with rollback',
    ],
  ),
  _ArchitectureTab(
    id: 'boot',
    name: 'Thin Boot & DI',
    badge: 'LIFECYCLE_BOOT',
    icon: 'cpu',
    description:
        'Handles environment loading, DI registration, logging, and router '
        'initialization cleanly before runApp().',
    filename: 'lib/main.dart',
    code: '''// lib/main.dart
Future<void> main() async {
  // 1. Boot environment & DI container
  await Bloom.boot(config: 'bloom.yaml');

  // 2. Inject singletons cleanly
  inject<AuthService>();

  // 3. Launch application
  runApp(const MyApp());
}''',
    highlights: [
      'Deterministic boot pipeline prevents null states',
      'Scoped DI container without global service locator pollution',
      'Unified environment manifest in `bloom.yaml`',
    ],
  ),
];

BloomNode buildArchitecturePlayground() {
  final activeTabId = signal('routing');

  return Div(
    className:
        'p-5 sm:p-8 lg:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur '
        'border border-slate-200 dark:border-zinc-800 shadow-2xl relative '
        'overflow-hidden max-w-6xl mx-auto text-left',
    children: [
      // Ambient Glow
      Div(
        className:
            'absolute top-0 right-0 w-96 h-96 bg-purple-500/5 rounded-full '
            'blur-3xl pointer-events-none',
      ),

      // Tab Selectors
      Div(
        className:
            'flex items-center gap-2 mb-8 pb-4 border-b border-slate-200 '
            'dark:border-zinc-800 relative z-10 overflow-x-auto no-scrollbar',
        children: [
          for (final tab in _tabs)
            Live(() {
              final isActive = activeTabId.value == tab.id;
              return Button(
                attrs: {'type': 'button'},
                onClick: (_) => activeTabId.value = tab.id,
                className:
                    'flex items-center gap-2 px-4 py-2.5 rounded-xl font-bold '
                    'text-xs tracking-tight transition-all duration-200 border cursor-pointer ${isActive ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-950 border-slate-900 dark:border-white shadow-lg shadow-white/10 scale-105 font-black' : 'bg-slate-100 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-zinc-800 hover:text-slate-900 dark:hover:text-white hover:border-slate-300 dark:hover:border-zinc-700'}',
                children: [
                  hugeIcon(tab.icon, className: 'w-4 h-4'),
                  Span(text: tab.name),
                ],
              );
            }),
        ],
      ),

      // Main Playground Grid
      Live(() {
        final current = _tabs.firstWhere(
          (t) => t.id == activeTabId.value,
          orElse: () => _tabs.first,
        );

        return Div(
          className: 'grid grid-cols-1 lg:grid-cols-12 gap-8 items-start relative z-10',
          children: [
            // Left Pane: Descriptions & Highlights
            Div(
              className: 'lg:col-span-5 space-y-5',
              children: [
                Div(
                  className: 'flex items-center gap-2',
                  children: [
                    Span(
                      className:
                          'px-3 py-1 rounded-full bg-purple-500/10 text-purple-600 '
                          'dark:text-purple-400 text-xs font-mono font-bold '
                          'border border-purple-500/20',
                      text: current.badge,
                    ),
                  ],
                ),
                H3(
                  className:
                      'text-2xl sm:text-3xl font-black text-slate-900 dark:text-white '
                      'tracking-tight',
                  text: current.name,
                ),
                P(
                  className:
                      'text-sm text-slate-600 dark:text-slate-300 '
                      'leading-relaxed font-normal',
                  text: current.description,
                ),
                Div(
                  className: 'space-y-3 pt-2',
                  children: [
                    for (final highlight in current.highlights)
                      Div(
                        className:
                            'flex items-start gap-2.5 text-xs sm:text-sm '
                            'text-slate-700 dark:text-slate-200 font-medium',
                        children: [
                          hugeIcon(
                            'check-circle',
                            className:
                                'w-4 h-4 text-purple-600 dark:text-purple-400 '
                                'shrink-0 mt-0.5',
                          ),
                          Span(text: highlight),
                        ],
                      ),
                  ],
                ),
              ],
            ),

            // Right Pane: Code Editor
            Div(
              className: 'lg:col-span-7',
              children: [
                Div(
                  className:
                      'rounded-2xl overflow-hidden bg-slate-950 dark:bg-black '
                      'border border-slate-800 dark:border-zinc-800 shadow-2xl '
                      'font-mono text-xs',
                  children: [
                    Div(
                      className:
                          'flex items-center justify-between px-4 py-3 bg-slate-900 '
                          'dark:bg-zinc-950 border-b border-slate-800 '
                          'dark:border-zinc-800',
                      children: [
                        Div(
                          className: 'flex items-center gap-2',
                          children: [
                            Div(
                              className:
                                  'w-2.5 h-2.5 rounded-full bg-rose-500/80',
                            ),
                            Div(
                              className:
                                  'w-2.5 h-2.5 rounded-full bg-amber-500/80',
                            ),
                            Div(
                              className:
                                  'w-2.5 h-2.5 rounded-full bg-emerald-500/80',
                            ),
                            Span(
                              className:
                                  'ml-2 text-[11px] text-slate-400 font-bold',
                              text: 'bloom-playground.dart',
                            ),
                          ],
                        ),
                        Span(
                          className: 'text-[10px] text-purple-400 font-bold',
                          text: 'AOT_SAFE',
                        ),
                      ],
                    ),
                    Pre(
                      className:
                          'p-5 text-slate-100 leading-relaxed overflow-x-auto '
                          'font-mono text-xs',
                      children: [
                        Code(className: 'language-dart', text: current.code),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      }),
    ],
  );
}
