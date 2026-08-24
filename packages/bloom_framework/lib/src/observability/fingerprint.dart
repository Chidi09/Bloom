/// Deterministic crash and exception fingerprinting utilities.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilities for calculating deterministic crash grouping fingerprints.
///
/// Normalizes dynamic data (UUIDs, hex addresses, numeric IDs) and extracts user-space
/// stack frames to group identical root-cause errors together in telemetry backends.
///
/// Example:
/// ```dart
/// final tokens = BloomCrashFingerprint.compute(
///   exceptionType: 'FormatException',
///   message: 'Invalid UUID: 123e4567-e89b-12d3-a456-426614174000',
/// );
/// final hash = BloomCrashFingerprint.hashTokens(tokens);
/// ```
class BloomCrashFingerprint {
  static final RegExp _vmFramePattern = RegExp(r'#\d+\s+([^\s(]+)');
  static final RegExp _webFramePattern = RegExp(r'^\s*at\s+([^\s(]+)');
  static final RegExp _uuidPattern = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
  static final RegExp _hexPattern = RegExp(r'0x[0-9a-fA-F]+');
  static final RegExp _digitsPattern = RegExp(r'\b\d+\b');

  /// Normalizes dynamic tokens (UUIDs, hex addresses, integers) in error messages.
  static String sanitizeMessage(String message) {
    if (message.isEmpty) return '';
    final firstLine = message.split('\n').first.trim();
    return firstLine
        .replaceAll(_uuidPattern, '<UUID>')
        .replaceAll(_hexPattern, '<HEX>')
        .replaceAll(_digitsPattern, '#');
  }

  /// Computes a deterministic list of fingerprint tokens and SHA-256 hash.
  ///
  /// Extracts top non-framework stack frames and combines them with the [exceptionType].
  static List<String> compute({
    required String exceptionType,
    required String message,
    String? stackTrace,
    List<String>? customFingerprint,
  }) {
    if (customFingerprint != null && customFingerprint.isNotEmpty) {
      return List<String>.from(customFingerprint);
    }

    final tokens = <String>[exceptionType];

    if (stackTrace != null && stackTrace.isNotEmpty) {
      final lines = stackTrace.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Skip internal SDK / dart runtime frames to group by user code
        if (trimmed.contains('package:flutter/') ||
            trimmed.contains('dart:async') ||
            trimmed.contains('dart:isolate') ||
            trimmed.contains('dart:core') ||
            trimmed.contains('dart_sdk.js') ||
            trimmed.contains('package:bloom_framework/src/observability')) {
          continue;
        }

        // Match frame symbol (e.g. #0 CartController.addItem or at CartController.addItem)
        final vmMatch = _vmFramePattern.firstMatch(trimmed);
        if (vmMatch != null) {
          tokens.add(vmMatch.group(1)!);
        } else {
          final webMatch = _webFramePattern.firstMatch(trimmed);
          if (webMatch != null) {
            tokens.add(webMatch.group(1)!);
          }
        }
        if (tokens.length >= 4) break; // Take up to top 3 user frames
      }
    }

    if (tokens.length == 1 && message.isNotEmpty) {
      // If no stack frames could be parsed, use sanitized message prefix
      tokens.add(sanitizeMessage(message));
    }

    return tokens;
  }

  /// Calculates a SHA-256 hex string from the fingerprint [tokens].
  static String hashTokens(List<String> tokens) {
    final raw = tokens.join('|');
    return sha256.convert(utf8.encode(raw)).toString();
  }
}

