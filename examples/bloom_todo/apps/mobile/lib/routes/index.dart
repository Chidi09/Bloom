import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/guards.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthGuard.isAuthenticated) {
        context.go('/today');
      } else {
        context.go('/login');
      }
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
