// lib/src/templates/template_registry.dart

class StarterTemplate {
  final String name;
  final String description;
  final String category;
  final List<String> includedFeatures;

  const StarterTemplate({
    required this.name,
    required this.description,
    required this.category,
    required this.includedFeatures,
  });
}

/// Official and community starter templates registry.
class TemplateRegistry {
  static const List<StarterTemplate> officialTemplates = [
    StarterTemplate(
      name: 'default',
      description: 'Standard modern Bloom application with file-based routing and reactive signals.',
      category: 'General',
      includedFeatures: ['Signals State', 'GoRouter', 'BloomData Cache', 'DevTools Overlay'],
    ),
    StarterTemplate(
      name: 'ecommerce',
      description: 'E-commerce storefront with product catalog, cart manager, and checkout flow.',
      category: 'Commerce',
      includedFeatures: ['Product Grid', 'Cart Controller', 'Payment Form', 'Offline Queue'],
    ),
    StarterTemplate(
      name: 'social',
      description: 'Social networking app with user profiles, activity feeds, and photo uploads.',
      category: 'Community',
      includedFeatures: ['Feed View', 'Camera Capture', 'Auth Guard', 'Image Optimizer'],
    ),
    StarterTemplate(
      name: 'fullstack',
      description: 'Full-stack application with API backend routes, Serverpod/Supabase, and SSR.',
      category: 'Full-Stack',
      includedFeatures: ['API Router', 'Database Adapter', 'SSR Engine', 'PWA Support'],
    ),
    StarterTemplate(
      name: 'minimal',
      description: 'Barebones single-screen template for micro-apps and rapid prototyping.',
      category: 'Minimal',
      includedFeatures: ['Single Page', 'Counter Controller'],
    ),
  ];

  /// Finds an official template by name.
  static StarterTemplate? findTemplate(String name) {
    final lower = name.trim().toLowerCase();
    return officialTemplates.firstWhere(
      (t) => t.name == lower,
      orElse: () => officialTemplates.first,
    );
  }

  /// Checks whether a template name represents a remote GitHub/Git URI.
  static bool isRemoteTemplate(String template) {
    return template.startsWith('github:') ||
        template.startsWith('https://') ||
        template.startsWith('git@');
  }
}
