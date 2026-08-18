// lib/src/updates/update_manifest.dart

/// Manifest describing a downloadable Over-The-Air (OTA) patch.
class UpdateManifest {
  /// Unique patch identifier (e.g. `'patch_12'`).
  final String id;

  /// Semantic version string of the patch release.
  final String version;

  /// SHA-256 runtime fingerprint compatibility hash.
  final String runtimeFingerprint;

  /// Staged rollout deployment percentage [1..100].
  final int rolloutPercentage;

  /// Deployment channel (e.g. `'production'`, `'staging'`).
  final String channel;

  /// Deployment git branch.
  final String branch;

  /// Optional release notes markdown text.
  final String? releaseNotes;

  /// Download URL for patch binary assets.
  final String? downloadUrl;

  /// SHA-256 integrity hash of downloadable patch binary.
  final String? assetHash;

  /// Whether this update is mandatory for continued application use.
  final bool isMandatory;

  /// Additional custom patch metadata dictionary.
  final Map<String, dynamic> metadata;

  /// Creates an [UpdateManifest] descriptor.
  const UpdateManifest({
    required this.id,
    required this.version,
    required this.runtimeFingerprint,
    this.rolloutPercentage = 100,
    this.channel = 'production',
    this.branch = 'main',
    this.releaseNotes,
    this.downloadUrl,
    this.assetHash,
    this.isMandatory = false,
    this.metadata = const {},
  });

  /// Constructs an [UpdateManifest] from a JSON map.
  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    return UpdateManifest(
      id: json['id']?.toString() ?? 'unknown_patch',
      version: json['version']?.toString() ?? '1.0.0',
      runtimeFingerprint: json['runtime_fingerprint']?.toString() ?? '',
      rolloutPercentage: (json['rollout_percentage'] as num?)?.toInt() ?? 100,
      channel: json['channel']?.toString() ?? 'production',
      branch: json['branch']?.toString() ?? 'main',
      releaseNotes: json['release_notes']?.toString(),
      downloadUrl: json['download_url']?.toString(),
      assetHash: json['asset_hash']?.toString(),
      isMandatory: json['is_mandatory'] == true,
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : {},
    );
  }

  /// Serializes manifest to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'runtime_fingerprint': runtimeFingerprint,
      'rollout_percentage': rolloutPercentage,
      'channel': channel,
      'branch': branch,
      if (releaseNotes != null) 'release_notes': releaseNotes,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (assetHash != null) 'asset_hash': assetHash,
      'is_mandatory': isMandatory,
      'metadata': metadata,
    };
  }
}

/// Result returned from BloomUpdates.checkForUpdate().
class UpdateCheckResult {
  /// Whether an update was discovered.
  final bool isAvailable;

  /// Whether the discovered update is compatible with the local runtime binary.
  final bool isCompatible;

  /// Downloadable patch manifest if available.
  final UpdateManifest? manifest;

  /// Reason why update was rejected or unavailable.
  final String? rejectionReason;

  /// Creates an [UpdateCheckResult].
  const UpdateCheckResult({
    required this.isAvailable,
    this.isCompatible = true,
    this.manifest,
    this.rejectionReason,
  });

  /// Result representing an up-to-date client.
  const UpdateCheckResult.upToDate()
      : isAvailable = false,
        isCompatible = true,
        manifest = null,
        rejectionReason = null;

  /// Result representing a rejected update check.
  const UpdateCheckResult.rejected({
    required String reason,
    UpdateManifest? manifest,
  })  : isAvailable = false,
        isCompatible = false,
        manifest = manifest,
        rejectionReason = reason;

  /// Result representing an available and compatible update.
  const UpdateCheckResult.available(UpdateManifest updateManifest)
      : isAvailable = true,
        isCompatible = true,
        manifest = updateManifest,
        rejectionReason = null;
}
