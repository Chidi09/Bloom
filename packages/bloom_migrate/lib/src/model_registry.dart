// lib/src/model_registry.dart
import 'package:bloom_db/bloom_db.dart';

/// Registry holding [ModelMeta] metadata definitions for migration generation.
class BloomModelRegistry {
  BloomModelRegistry._();

  static final BloomModelRegistry instance = BloomModelRegistry._();

  final Map<String, List<ModelMeta>> _modelsByApp = {};

  /// Registers a [ModelMeta] definition into the registry.
  void register(ModelMeta meta) {
    _modelsByApp.putIfAbsent(meta.appLabel, () => []).add(meta);
  }

  /// Registers multiple [ModelMeta] definitions.
  void registerAll(Iterable<ModelMeta> metas) {
    for (final meta in metas) {
      register(meta);
    }
  }

  /// Retrieves all registered [ModelMeta] definitions for a specific [appLabel].
  List<ModelMeta> getModelsForApp(String appLabel) {
    return List.unmodifiable(_modelsByApp[appLabel] ?? []);
  }

  /// Retrieves all registered [ModelMeta] definitions across all apps.
  List<ModelMeta> get allModels {
    return _modelsByApp.values.expand((list) => list).toList();
  }

  /// Clears the registry (useful for testing).
  void clear() {
    _modelsByApp.clear();
  }
}
