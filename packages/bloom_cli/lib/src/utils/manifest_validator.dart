import 'dart:io';

import 'package:yaml/yaml.dart';

import '../deployment/deployment_target_detector.dart';

/// Validates the core Bloom manifest contract used by the CLI.
///
/// Plugin-owned and future fields remain open. This checks fields whose values
/// change how Bloom selects and runs a project, so `doctor` and CI can catch
/// configuration mistakes before a build starts.
class BloomManifestValidator {
  const BloomManifestValidator._();

  static List<String> validateFile(File file) {
    if (!file.existsSync()) return const ['bloom.yaml is missing'];

    final Object? document;
    try {
      document = loadYaml(file.readAsStringSync());
    } catch (error) {
      return ['bloom.yaml could not be parsed: $error'];
    }

    if (document is! Map) {
      return const ['bloom.yaml must contain a mapping at its root'];
    }

    final config = document;
    final issues = <String>[];

    final name = config['name'];
    if (name is! String || name.trim().isEmpty) {
      issues.add('name must be a non-empty string');
    }

    final schema = config['schema'];
    if (schema != null && (schema is! int || schema < 1)) {
      issues.add('schema must be a positive integer');
    }

    final mode = config['mode'];
    if (mode != null &&
        (mode is! String ||
            !const {'managed', 'bare'}.contains(mode.toLowerCase()))) {
      issues.add('mode must be either "managed" or "bare"');
    }

    final target = config['target'];
    if (target != null && !_isSupportedTarget(target, allowWeb: true)) {
      issues.add('target must be a supported Bloom target or "web_dom"/"web"');
    }

    final deployment = config['deployment'];
    if (deployment != null && deployment is! Map) {
      issues.add('deployment must be a mapping');
    } else if (deployment is Map &&
        deployment['target'] != null &&
        !_isSupportedTarget(deployment['target'])) {
      issues
          .add('deployment.target must be a supported Bloom deployment target');
    }

    return issues;
  }

  static bool _isSupportedTarget(Object? value, {bool allowWeb = false}) {
    if (value is! String) return false;
    if (allowWeb && (value == 'web' || value == 'web_dom')) return true;
    return BloomDeploymentTarget.parse(value) != null;
  }
}
