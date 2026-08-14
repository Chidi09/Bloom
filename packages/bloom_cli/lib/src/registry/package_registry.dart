// lib/src/registry/package_registry.dart

enum VerificationTier {
  official,
  verified,
  community;

  String get displayName {
    switch (this) {
      case VerificationTier.official:
        return '🏆 Official';
      case VerificationTier.verified:
        return '🛡️ Verified';
      case VerificationTier.community:
        return '🌐 Community';
    }
  }
}

class MatrixTestResult {
  final String platform;
  final String flutterVersion;
  final bool isSuccess;
  final String? error;

  const MatrixTestResult({
    required this.platform,
    required this.flutterVersion,
    required this.isSuccess,
    this.error,
  });
}

class RegistryPackage {
  final String name;
  final String description;
  final String version;
  final String publisher;
  final bool isCoreTeam;
  final List<MatrixTestResult> matrixResults;
  final Map<String, String> platformSupport;

  const RegistryPackage({
    required this.name,
    required this.description,
    required this.version,
    required this.publisher,
    this.isCoreTeam = false,
    this.matrixResults = const [],
    this.platformSupport = const {},
  });

  /// Verification tier is derived strictly from core team ownership or automated CI matrix results (A2/A3).
  VerificationTier get tier {
    if (isCoreTeam) {
      return VerificationTier.official;
    }
    if (matrixResults.isNotEmpty && matrixResults.every((r) => r.isSuccess)) {
      return VerificationTier.verified;
    }
    return VerificationTier.community;
  }

  String get badge => tier.displayName;
}

/// Official and verified Bloom ecosystem package directory.
class PackageRegistry {
  static final List<RegistryPackage> _curatedPackages = [
    const RegistryPackage(
      name: 'bloom_camera',
      description: 'High-performance native camera capture and barcode scanning with fallback simulators.',
      version: '1.2.0',
      publisher: 'bloom.dev',
      isCoreTeam: true,
      platformSupport: {'android': '>=24', 'ios': '>=15.0', 'web': 'WebRTC'},
    ),
    const RegistryPackage(
      name: 'bloom_stripe',
      description: 'Native Stripe Payment Sheet and Elements checkout flows.',
      version: '0.9.4',
      publisher: 'community@fintech.io',
      isCoreTeam: false,
      matrixResults: [
        MatrixTestResult(platform: 'android', flutterVersion: '3.27.0', isSuccess: true),
        MatrixTestResult(platform: 'ios', flutterVersion: '3.27.0', isSuccess: true),
      ],
      platformSupport: {'android': '>=21', 'ios': '>=14.0'},
    ),
    const RegistryPackage(
      name: 'bloom_auth_supabase',
      description: 'Zero-config Supabase Authentication and RLS provider for Bloom Data.',
      version: '2.1.0',
      publisher: 'bloom.dev',
      isCoreTeam: true,
      platformSupport: {'android': 'all', 'ios': 'all', 'web': 'all'},
    ),
    const RegistryPackage(
      name: 'bloom_charts',
      description: 'Interactive hardware-accelerated charting and canvas rendering.',
      version: '0.4.1',
      publisher: 'dev_user@github',
      isCoreTeam: false,
      matrixResults: [
        MatrixTestResult(platform: 'android', flutterVersion: '3.27.0', isSuccess: false, error: 'NDK mismatch'),
      ],
      platformSupport: {'android': '>=26'},
    ),
  ];

  static List<RegistryPackage> get allPackages => List.unmodifiable(_curatedPackages);

  /// Search packages matching a text query.
  static List<RegistryPackage> search(String query) {
    if (query.trim().isEmpty) return allPackages;
    final lower = query.toLowerCase();
    return _curatedPackages.where((p) {
      return p.name.toLowerCase().contains(lower) ||
          p.description.toLowerCase().contains(lower) ||
          p.publisher.toLowerCase().contains(lower);
    }).toList();
  }

  /// Finds a specific package by name.
  static RegistryPackage? findPackage(String name) {
    final lower = name.trim().toLowerCase();
    return _curatedPackages.firstWhere(
      (p) => p.name.toLowerCase() == lower,
      orElse: () => throw ArgumentError('Package "$name" not found in Bloom Registry.'),
    );
  }
}
