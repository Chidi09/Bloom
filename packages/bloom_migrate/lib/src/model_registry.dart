// lib/src/model_registry.dart
import 'package:bloom_db/bloom_db.dart';

/// Registry holding [ModelMeta] metadata definitions for migration generation.
///
/// [BloomModelRegistry] acts as a central store for `@BloomModel` entity metadata descriptors,
/// grouping them by application namespace (`appLabel`). Used by schema generators and CLI tooling
/// to calculate table schemas, relations, and dependency ordering.
///
/// Example:
/// ```dart
/// final registry = BloomModelRegistry.instance;
///
/// // Register model metadata
/// registry.register(UserModelMeta);
/// registry.register(PostModelMeta);
///
/// // Retrieve models for an app
/// final blogModels = registry.getModelsForApp('blog');
///
/// // Retrieve all registered models across apps
/// final all = registry.allModels;
/// ```
class BloomModelRegistry {
  BloomModelRegistry._();

  /// The global singleton [BloomModelRegistry] instance.
  static final BloomModelRegistry instance = BloomModelRegistry._();

  final Map<String, List<ModelMeta>> _modelsByApp = {};

  /// Registers a [ModelMeta] definition into the registry under its [ModelMeta.appLabel].
  ///
  /// Example:
  /// ```dart
  /// BloomModelRegistry.instance.register(AccountModelMeta);
  /// ```
  void register(ModelMeta meta) {
    _modelsByApp.putIfAbsent(meta.appLabel, () => []).add(meta);
  }

  /// Registers multiple [ModelMeta] definitions in bulk.
  ///
  /// Example:
  /// ```dart
  /// BloomModelRegistry.instance.registerAll([
  ///   UserModelMeta,
  ///   RoleModelMeta,
  ///   PermissionModelMeta,
  /// ]);
  /// ```
  void registerAll(Iterable<ModelMeta> metas) {
    for (final meta in metas) {
      register(meta);
    }
  }

  /// Retrieves an unmodifiable list of registered [ModelMeta] definitions for a specific [appLabel].
  ///
  /// Returns an empty list if no models have been registered for [appLabel].
  ///
  /// Example:
  /// ```dart
  /// final authModels = BloomModelRegistry.instance.getModelsForApp('auth');
  /// ```
  List<ModelMeta> getModelsForApp(String appLabel) {
    return List.unmodifiable(_modelsByApp[appLabel] ?? []);
  }

  /// Retrieves a flattened list of all registered [ModelMeta] definitions across all apps.
  ///
  /// Example:
  /// ```dart
  /// final all = BloomModelRegistry.instance.allModels;
  /// print('Total registered models: ${all.length}');
  /// ```
  List<ModelMeta> get allModels {
    return _modelsByApp.values.expand((list) => list).toList();
  }

  /// Clears all registered models from the registry.
  ///
  /// Useful for resetting state between test runs.
  ///
  /// Example:
  /// ```dart
  /// BloomModelRegistry.instance.clear();
  /// ```
  void clear() {
    _modelsByApp.clear();
  }
}
