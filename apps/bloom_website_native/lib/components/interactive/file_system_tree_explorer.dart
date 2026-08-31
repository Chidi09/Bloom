import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

class _RouteFile {
  final String id;
  final String path;
  final String urlRoute;
  final String guard;
  final String type;
  final String codeSnippet;

  const _RouteFile({
    required this.id,
    required this.path,
    required this.urlRoute,
    required this.guard,
    required this.type,
    required this.codeSnippet,
  });
}

const _routes = <_RouteFile>[
  _RouteFile(
    id: 'index',
    path: 'index.dart',
    urlRoute: '/',
    guard: 'None (Public)',
    type: 'Root View',
    codeSnippet: '''// lib/app/routes/index.dart
@RoutePage()
class HomeView extends BloomView<HomeController> {
  @override
  Widget build(BuildContext context) => Scaffold(body: HomeHero());
}''',
  ),
  _RouteFile(
    id: 'login',
    path: '(auth) / login.dart',
    urlRoute: '/login',
    guard: 'GuestGuard',
    type: 'Grouped Route',
    codeSnippet: '''// lib/app/routes/(auth)/login.dart
@RoutePage()
class LoginView extends BloomView<LoginController> {
  @override
  Widget build(BuildContext context) => LoginForm();
}''',
  ),
  _RouteFile(
    id: 'product',
    path: 'products / [id].dart',
    urlRoute: '/products/42',
    guard: 'AuthGuard',
    type: 'Dynamic Parameter',
    codeSnippet: '''// lib/app/routes/products/[id].dart
@RoutePage()
class ProductDetailsView extends BloomPage {
  @PathParam('id')
  final String productId;

  ProductDetailsView({required this.productId});
}''',
  ),
  _RouteFile(
    id: 'layout',
    path: '_layout.dart',
    urlRoute: '/_layout',
    guard: 'AppGuard',
    type: 'Scaffold Layout',
    codeSnippet: '''// lib/app/routes/_layout.dart
class RootScaffold extends BloomLayout {
  @override
  Widget build(BuildContext context, Widget child) {
    return MainShell(navigationBar: BottomBar(), body: child);
  }
}''',
  ),
];

BloomNode fileSystemTreeExplorer() {
  final activeRouteId = signal('index');

  return Div(
    className:
        'p-5 sm:p-8 lg:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur '
        'border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl '
        'mx-auto space-y-8 text-left',
    children: [
      // Header
      Div(
        className:
            'flex flex-col sm:flex-row sm:items-center justify-between gap-4 '
            'pb-6 border-b border-slate-200 dark:border-zinc-800',
        children: [
          Div(
            children: [
              Div(
                className: 'flex items-center gap-2 mb-1',
                children: [
                  hugeIcon(
                    'folder',
                    className: 'w-5 h-5 text-purple-600 dark:text-purple-400',
                  ),
                  H3(
                    className:
                        'text-xl font-bold text-slate-900 dark:text-white '
                        'tracking-tight',
                    text: 'Interactive File-System Routing Visualizer',
                  ),
                ],
              ),
              P(
                className: 'text-xs text-slate-600 dark:text-slate-400',
                text:
                    'Click files in the directory tree to inspect automatically '
                    'mapped go_router definitions.',
              ),
            ],
          ),
        ],
      ),

      // Grid: Tree vs Mapped Route
      Div(
        className: 'grid grid-cols-1 lg:grid-cols-12 gap-8 items-start',
        children: [
          // Left: Directory Tree
          Div(
            className:
                'lg:col-span-5 p-5 rounded-2xl bg-slate-50 dark:bg-zinc-950 '
                'border border-slate-200 dark:border-zinc-800 space-y-3 '
                'font-mono text-xs',
            children: [
              Div(
                className:
                    'text-[11px] font-bold text-slate-500 dark:text-slate-400 '
                    'pb-2 border-b border-slate-200 dark:border-zinc-800',
                text: '📁 lib / app / routes /',
              ),
              Div(
                className: 'space-y-1.5 pt-1',
                children: [
                  for (final r in _routes)
                    Live(() {
                      final isActive = activeRouteId.value == r.id;
                      return Button(
                        attrs: {'type': 'button'},
                        onClick: (_) => activeRouteId.value = r.id,
                        className:
                            'w-full p-2.5 rounded-xl text-left transition flex '
                            'items-center justify-between border cursor-pointer ${isActive ? 'bg-purple-600 text-white font-bold border-purple-600 shadow-md' : 'bg-white dark:bg-zinc-900 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-zinc-800 hover:border-purple-400'}',
                        children: [
                          Span(className: 'truncate', text: '📄 ${r.path}'),
                          Span(
                            className:
                                'text-[10px] px-1.5 py-0.5 rounded ${isActive ? 'bg-purple-700 text-white' : 'bg-slate-100 dark:bg-zinc-800 text-slate-500 dark:text-slate-400'}',
                            text: r.type.split(' ').first,
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ],
          ),

          // Right: Generated Route Details
          Live(() {
            final activeRoute = _routes.firstWhere(
              (r) => r.id == activeRouteId.value,
              orElse: () => _routes.first,
            );

            return Div(
              className: 'lg:col-span-7 space-y-4',
              children: [
                Div(
                  className:
                      'p-4 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
                      'border-slate-200 dark:border-zinc-800 flex items-center '
                      'justify-between font-mono text-xs',
                  children: [
                    Div(
                      children: [
                        Span(
                          className:
                              'text-[10px] text-slate-500 dark:text-slate-400 '
                              'block font-bold',
                          text: 'MAPPED ROUTE PATH',
                        ),
                        Span(
                          className:
                              'text-sm font-bold text-purple-600 dark:text-purple-400',
                          text: activeRoute.urlRoute,
                        ),
                      ],
                    ),
                    Div(
                      className: 'text-right',
                      children: [
                        Span(
                          className:
                              'text-[10px] text-slate-500 dark:text-slate-400 '
                              'block font-bold',
                          text: 'ROUTE GUARD',
                        ),
                        Span(
                          className:
                              'text-xs font-semibold text-emerald-600 dark:text-emerald-400',
                          text: activeRoute.guard,
                        ),
                      ],
                    ),
                  ],
                ),
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
                        Span(
                          className: 'text-[11px] text-slate-400 font-bold',
                          text: activeRoute.path,
                        ),
                        Span(
                          className: 'text-[10px] text-purple-400 font-bold',
                          text: 'AUTO_COMPILED',
                        ),
                      ],
                    ),
                    Pre(
                      className:
                          'p-5 text-slate-100 leading-relaxed overflow-x-auto '
                          'font-mono text-xs',
                      children: [
                        Code(
                          className: 'language-dart',
                          text: activeRoute.codeSnippet,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    ],
  );
}
