// lib/src/observability/fingerprint.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilities for calculating deterministic crash grouping fingerprints.
class BloomCrashFingerprint {
  /// Computes a deterministic list of fingerprint tokens and SHA-256 hash.
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
            trimmed.contains('package:bloom_framework/src/observability')) {
          continue;
        }

        // Match frame symbol (e.g. #0 CartController.addItem)
        final match = RegExp(r'#\d+\s+([^\s]+)').firstMatch(trimmed);
        if (match != null) {
          tokens.add(match.group(1)!);
        }
        if (tokens.length >= 4) break; // Take up to top 3 user frames
      }
    }

    if (tokens.length == 1 && message.isNotEmpty) {
      // If no stack frames could be parsed, use sanitized message prefix
      final sanitizedMsg = message.split('\n').first.replaceAll(RegExp(r'\d+'), '#');
      tokens.add(sanitizedMsg);
    }

    return tokens;
  }

  /// Calculates a SHA-256 hex string from the fingerprint tokens.
  static String hashTokens(List<String> tokens) {
    final raw = tokens.join('|');
    return sha256.convert(utf8.encode(raw)).toString();
  }
}
