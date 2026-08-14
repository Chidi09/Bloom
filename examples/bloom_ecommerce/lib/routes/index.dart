// lib/routes/index.dart
import 'package:flutter/material.dart';
import 'catalog/index.dart';

class IndexRoute extends StatelessWidget {
  const IndexRoute({super.key});

  @override
  Widget build(BuildContext context) => const CatalogIndexRoute();
}
