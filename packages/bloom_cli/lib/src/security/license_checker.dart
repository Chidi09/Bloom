// lib/src/security/license_checker.dart

enum LicenseRiskLevel {
  permissive,
  weakCopyleft,
  strongCopyleft,
  unknown;

  String toJson() => name;
}

class PackageLicenseResult {
  final String package;
  final String license;
  final LicenseRiskLevel riskLevel;

  PackageLicenseResult({
    required this.package,
    required this.license,
    required this.riskLevel,
  });
}

/// Evaluates open-source license compliance across project dependencies.
class LicenseChecker {
  static const Set<String> _permissiveLicenses = {
    'mit',
    'apache-2.0',
    'apache 2.0',
    'bsd-2-clause',
    'bsd-3-clause',
    'bsd',
    'isc',
    'unlicense',
    '0bsd',
  };

  static const Set<String> _strongCopyleftLicenses = {
    'gpl-2.0',
    'gpl-3.0',
    'gplv2',
    'gplv3',
    'agpl-3.0',
    'agplv3',
  };

  static const Set<String> _weakCopyleftLicenses = {
    'lgpl-2.1',
    'lgpl-3.0',
    'lgplv2.1',
    'lgplv3',
    'mpl-2.0',
  };

  /// Evaluates the risk level for a given package and license string.
  static PackageLicenseResult evaluate(String package, String licenseString) {
    final lower = licenseString.trim().toLowerCase();

    if (_permissiveLicenses.contains(lower)) {
      return PackageLicenseResult(
        package: package,
        license: licenseString,
        riskLevel: LicenseRiskLevel.permissive,
      );
    }

    if (_strongCopyleftLicenses.contains(lower)) {
      return PackageLicenseResult(
        package: package,
        license: licenseString,
        riskLevel: LicenseRiskLevel.strongCopyleft,
      );
    }

    if (_weakCopyleftLicenses.contains(lower)) {
      return PackageLicenseResult(
        package: package,
        license: licenseString,
        riskLevel: LicenseRiskLevel.weakCopyleft,
      );
    }

    return PackageLicenseResult(
      package: package,
      license: licenseString.isEmpty ? 'Unknown' : licenseString,
      riskLevel: LicenseRiskLevel.permissive, // Default standard pub packages
    );
  }
}
