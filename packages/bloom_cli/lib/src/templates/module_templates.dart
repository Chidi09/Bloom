// lib/src/templates/module_templates.dart

class BloomModuleTemplates {
  static String toPascalCase(String input) {
    return input
        .split(RegExp(r'[_\-\s]+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join();
  }

  static String toCamelCase(String input) {
    final pascal = toPascalCase(input);
    if (pascal.isEmpty) return '';
    return pascal[0].toLowerCase() + pascal.substring(1);
  }

  static String moduleYaml({
    required String name,
    required String description,
  }) {
    return '''# bloom.module.yaml - Bloom Native Module Manifest
name: $name
version: 0.1.0
description: "$description"

platforms:
  android:
    min_sdk: 24
    target_sdk: 34
    dependencies:
      - "androidx.core:core-ktx:1.12.0"
  ios:
    min_version: "15.0"
    frameworks:
      - Foundation

permissions:
  $name:
    android: "android.permission.INTERNET"
    ios: "NSCameraUsageDescription"
    default_prompt: "Allow $name to access device capabilities."
    optional: false

config_plugin:
  class_name: ${toPascalCase(name)}ConfigPlugin
''';
  }

  static String pubspecYaml({
    required String name,
    required String description,
    String? frameworkPath,
  }) {
    String frameworkDep;
    if (frameworkPath != null) {
      frameworkDep = '''
  bloom_framework:
    path: $frameworkPath''';
    } else {
      frameworkDep = '''
  bloom_framework: ^0.1.0''';
    }

    return '''name: $name
description: "$description"
version: 0.1.0
publish_to: none

environment:
  sdk: '>=3.5.0 <4.0.0'
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
$frameworkDep

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
''';
  }

  static String dartModuleDefinition({required String name}) {
    final className = toPascalCase(name);
    return '''// lib/src/${name}.module.dart
import 'package:bloom_framework/bloom_modules.dart';

/// Declarative Bloom Module DSL definition for $name.
@BloomModule(
  name: '$className',
  version: '0.1.0',
  description: 'Native $name capability module for Bloom.',
)
abstract class ${className}Definition {
  @BloomConstant()
  String get moduleVersion;

  @BloomAsyncFunction(thread: NativeThread.background)
  Future<Map<String, dynamic>> executeAction({
    required String action,
    Map<String, dynamic>? parameters,
  });

  @BloomEvent()
  Stream<Map<String, dynamic>> get onStatusEvent;

  @BloomView(name: '${className}Preview')
  void previewView();

  @BloomLifecycleHook()
  void onHostResume();

  @BloomLifecycleHook()
  void onHostPause();
}
''';
  }

  static String dartPublicApi({required String name}) {
    final className = toPascalCase(name);
    return '''// lib/$name.dart
library $name;

export 'src/${name}.module.dart';
export 'src/${name}.g.dart';

/// Public interface for the $className Native Module implementing [${className}Definition].
class $className extends Bloom${className}Bridge {
  $className();
}
''';
  }

  static String kotlinModule({
    required String name,
    required String org,
  }) {
    final className = toPascalCase(name);
    final packagePath = org.replaceAll('-', '_');
    return '''package $packagePath.$name

import dev.bloom.modules.BloomNativeModule
import dev.bloom.modules.ModuleDefinition
import dev.bloom.modules.NativeThread

class ${className}Module : BloomNativeModule() {
    override fun definition(): ModuleDefinition = moduleDefinition {
        name("$className")

        constants(
            "moduleVersion" to "0.1.0"
        )

        asyncFunction("executeAction", NativeThread.BACKGROUND) { action: String, parameters: Map<String, Any>? ->
            mapOf(
                "status" to "success",
                "action" to action,
                "timestamp" to System.currentTimeMillis()
            )
        }

        event("onStatusEvent")
    }
}
''';
  }

  static String swiftModule({required String name}) {
    final className = toPascalCase(name);
    return '''// ios/Sources/${className}Module.swift
import Foundation
import BloomModuleCore

public class ${className}Module: BloomNativeModule {
    public override func definition() -> ModuleDefinition {
        Name("$className")

        Constants([
            "moduleVersion": "0.1.0"
        ])

        AsyncFunction("executeAction", on: .backgroundQueue) { (action: String, parameters: [String: Any]?, promise: Promise) in
            promise.resolve([
                "status": "success",
                "action": action,
                "timestamp": Date().timeIntervalSince1970
            ])
        }

        Event("onStatusEvent")
    }
}
''';
  }

  static String androidGradleKts({
    required String name,
    required String org,
  }) {
    final packagePath = org.replaceAll('-', '_');
    return '''plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "$packagePath.$name"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
}
''';
  }

  static String iosPodspec({
    required String name,
    required String description,
  }) {
    final className = toPascalCase(name);
    return '''Pod::Spec.new do |s|
  s.name             = '$className'
  s.version          = '0.1.0'
  s.summary          = '$description'
  s.homepage         = 'https://bloom.dev'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Bloom Platform' => 'team@bloom.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'Sources/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
end
''';
  }

  static String moduleTest({required String name}) {
    final className = toPascalCase(name);
    return '''// test/${name}_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';
import 'package:$name/$name.dart';

void main() {
  setUp(() {
    Bloom.reset();
  });

  test('$className registers into BloomModuleRegistry and has initialized state', () async {
    final registry = BloomModuleRegistry();
    final module = $className();

    await registry.registerModule(module);

    expect(registry.hasModule('$className'), isTrue);
    expect(module.isInitialized, isTrue);

    await registry.unregisterModule('$className');
    expect(registry.hasModule('$className'), isFalse);
  });
}
''';
  }

  static String moduleReadme({
    required String name,
    required String description,
  }) {
    final className = toPascalCase(name);
    return '''# $name

> $description

A native Bloom module built with the **Bloom Module DSL**.

## Installation

```bash
bloom add $name
```

## Usage

```dart
import 'package:$name/$name.dart';

final $name = inject<$className>();
final result = await $name.executeAction(action: 'initialize');
```
''';
  }
}
