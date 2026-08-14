// lib/main.dart
import 'package:bloom_framework/bloom.dart';
import 'package:flutter/material.dart';
import 'controllers/cart_controller.dart';
import 'routes/_layout.dart';
import 'routes/cart.dart';
import 'routes/catalog/index.dart';
import 'routes/orders.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register state controllers into Bloom DI container
  provideSingleton<CartController>(() => CartController());

  final router = GoRouter(
    initialLocation: '/catalog',
    routes: [
      ShellRoute(
        builder: (context, state, child) => Layout(child: child),
        routes: [
          GoRoute(
            path: '/catalog',
            builder: (context, state) => const CatalogIndexRoute(),
          ),
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartRoute(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersRoute(),
          ),
        ],
      ),
    ],
  );

  runApp(BloomCommerceApp(router: router));
}

class BloomCommerceApp extends StatelessWidget {
  final GoRouter router;
  const BloomCommerceApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bloom Commerce',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
