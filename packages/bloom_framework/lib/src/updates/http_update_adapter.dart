// lib/src/updates/http_update_adapter.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../core/logger.dart';
import 'bloom_updates.dart';
import 'update_manifest.dart';

/// Real HTTP / CDN network adapter for checking, downloading, and verifying OTA patches.
class BloomHttpUpdateAdapter implements BloomUpdateClientAdapter {
  /// Base API / CDN URL for updates.
  final String baseUrl;

  /// Underlying HTTP client instance.
  final http.Client httpClient;

  /// File system directory where downloaded patches are staged.
  final Directory stagingDir;

  /// Default HTTP headers included in update requests.
  final Map<String, String> defaultHeaders;

  /// Creates a [BloomHttpUpdateAdapter].
  BloomHttpUpdateAdapter({
    required this.baseUrl,
    http.Client? httpClient,
    Directory? stagingDir,
    this.defaultHeaders = const {},
  })  : httpClient = httpClient ?? http.Client(),
        stagingDir = stagingDir ?? Directory(p.join(Directory.systemTemp.path, 'bloom_updates_stage'));

  @override
  Future<UpdateManifest?> checkServerForUpdate({
    required String channel,
    required String branch,
    required String runtimeFingerprint,
    required String deviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/updates/check').replace(queryParameters: {
      'channel': channel,
      'branch': branch,
      'fingerprint': runtimeFingerprint,
      'device_id': deviceId,
    });

    logger.debug('BloomHttpUpdateAdapter: Checking update server at $uri');

    try {
      final response = await httpClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'BloomOTA/1.0.0',
          ...defaultHeaders,
        },
      );

      if (response.statusCode == 204 || response.statusCode == 404) {
        // No update available
        return null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['is_available'] == false || data['manifest'] == null && data['id'] == null) {
            return null;
          }
          final manifestMap = data['manifest'] is Map<String, dynamic>
              ? data['manifest'] as Map<String, dynamic>
              : data;
          return UpdateManifest.fromJson(manifestMap);
        }
      }

      logger.warn('BloomHttpUpdateAdapter: Server returned status ${response.statusCode}: ${response.body}');
      return null;
    } catch (e, st) {
      logger.error('BloomHttpUpdateAdapter: Check failed: $e', e, st);
      rethrow;
    }
  }

  @override
  Future<bool> downloadPatchAssets({
    required UpdateManifest manifest,
    required void Function(double progress) onProgress,
  }) async {
    if (manifest.downloadUrl == null || manifest.downloadUrl!.isEmpty) {
      throw StateError('Cannot download patch: manifest.downloadUrl is empty.');
    }

    final uri = Uri.parse(manifest.downloadUrl!);
    logger.info('BloomHttpUpdateAdapter: Downloading patch "${manifest.id}" from $uri');

    try {
      final request = http.Request('GET', uri);
      request.headers.addAll(defaultHeaders);

      final response = await httpClient.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download failed with HTTP status ${response.statusCode}', uri: uri);
      }

      final contentLength = response.contentLength ?? 0;
      final bytesBuilder = BytesBuilder(copy: false);
      var receivedBytes = 0;

      await for (final chunk in response.stream) {
        bytesBuilder.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0) {
          onProgress(receivedBytes / contentLength);
        } else {
          onProgress(0.5);
        }
      }

      final downloadedBytes = bytesBuilder.takeBytes();
      onProgress(1.0);

      // Verify SHA-256 integrity hash if provided in manifest
      if (manifest.assetHash != null && manifest.assetHash!.isNotEmpty) {
        final computedSha = sha256.convert(downloadedBytes).toString();
        if (computedSha.toLowerCase() != manifest.assetHash!.toLowerCase()) {
          throw StateError('Patch asset cryptographic integrity check failed: expected "${manifest.assetHash}", got "$computedSha"');
        }
        logger.debug('BloomHttpUpdateAdapter: Cryptographic asset hash verified: $computedSha');
      }

      // Stage patch file to disk
      if (!stagingDir.existsSync()) {
        stagingDir.createSync(recursive: true);
      }

      final patchFile = File(p.join(stagingDir.path, '${manifest.id}.patch'));
      patchFile.writeAsBytesSync(downloadedBytes);

      logger.info('BloomHttpUpdateAdapter: Staged patch "${manifest.id}" at ${patchFile.path} (${downloadedBytes.length} bytes)');
      return true;
    } catch (e, st) {
      logger.error('BloomHttpUpdateAdapter: Patch download error: $e', e, st);
      rethrow;
    }
  }

  @override
  Future<void> triggerAppReload() async {
    logger.info('BloomHttpUpdateAdapter: App reload triggered to activate staged patch.');
  }

  @override
  Future<void> purgeActivePatch() async {
    if (stagingDir.existsSync()) {
      try {
        stagingDir.deleteSync(recursive: true);
        logger.info('BloomHttpUpdateAdapter: Staged patches purged successfully.');
      } catch (e) {
        logger.warn('BloomHttpUpdateAdapter: Could not delete staging dir: $e');
      }
    }
  }
}
