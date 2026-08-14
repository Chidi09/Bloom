// lib/src/updates/update_manifest.dart

/// Manifest describing a downloadable Over-The-Air (OTA) patch.
class UpdateManifest {
  final String id;
  final String version;
  final String runtimeFingerprint;
  final int rolloutPercentage;
  final String channel;
  final String branch;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? assetHash;
  final bool isMandatory;
  final Map<String, dynamic> metadata;

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
  final bool isAvailable;
  final bool isCompatible;
  final UpdateManifest? manifest;
  final String? rejectionReason;

  const UpdateCheckResult({
    required this.isAvailable,
    this.isCompatible = true,
    this.manifest,
    this.rejectionReason,
  });

  const UpdateCheckResult.upToDate()
      : isAvailable = false,
        isCompatible = true,
        manifest = null,
        rejectionReason = null;

  const UpdateCheckResult.rejected({
    required String reason,
    UpdateManifest? manifest,
  })  : isAvailable = false,
        isCompatible = false,
        manifest = manifest,
        rejectionReason = reason;

  const UpdateCheckResult.available(UpdateManifest updateManifest)
      : isAvailable = true,
        isCompatible = true,
        manifest = updateManifest,
        rejectionReason = null;
}
