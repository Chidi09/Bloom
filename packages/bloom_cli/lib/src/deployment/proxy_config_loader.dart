// lib/src/deployment/proxy_config_loader.dart
import '../dev/dev_proxy.dart';

/// Loads and validates reverse proxy configuration rules from `bloom.yaml`.
///
/// ### Architectural Contract
/// - Shared single source of truth for proxy configuration across development (`bloom js dev`),
///   production builds (`bloom build`, `bloom js build`), SSR engine generation (`BloomSsrEngine`),
///   and static host deployment config generation (`BloomHostConfigGenerator`).
/// - Guarantees deterministic prefix routing order by sorting rules in descending order of
///   [BloomDevProxyRule.pathPrefix] length.
///
/// ### Prefix Ordering Guarantee
/// When reverse proxies or routing engines match incoming request paths against a list of prefix
/// rules sequentially, a shorter generic prefix (such as `/api`) would greedily shadow a longer,
/// more specific prefix (such as `/api/v2` or `/api/v2/auth`) if evaluated first.
/// Sorting by descending prefix length ensures that the most specific subpath is always evaluated
/// and matched before broader ancestor prefixes.
List<BloomDevProxyRule> loadProxyRules(Map<dynamic, dynamic> config) {
  final rawProxy = config['proxy'];
  if (rawProxy == null) {
    return const [];
  }

  if (rawProxy is! Map) {
    throw const FormatException(
      'Invalid "proxy" configuration in bloom.yaml: expected a YAML map.',
    );
  }

  final rules = <BloomDevProxyRule>[];
  for (final entry in rawProxy.entries) {
    final key = entry.key.toString();
    try {
      final rule = BloomDevProxyRule.fromYaml(key, entry.value);
      rules.add(rule);
    } on FormatException catch (e) {
      throw FormatException(
        'Invalid proxy rule for "$key" in bloom.yaml: ${e.message}',
      );
    } catch (e) {
      throw FormatException(
        'Invalid proxy rule for "$key" in bloom.yaml: $e',
      );
    }
  }

  // Sort rules by descending pathPrefix length so that longer, more specific
  // routes (e.g. '/api/v2') are evaluated before broader prefix matches
  // (e.g. '/api'), preventing earlier broader routes from shadowing specific subpaths.
  rules.sort((a, b) => b.pathPrefix.length.compareTo(a.pathPrefix.length));

  return rules;
}
