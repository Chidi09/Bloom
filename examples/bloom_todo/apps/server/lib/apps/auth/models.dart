class RefreshToken {
  final String id;
  final String userId;
  final String tokenHash;
  final String? deviceId;
  final String? userAgent;
  final DateTime expiresAt;
  final DateTime createdAt;

  const RefreshToken({
    required this.id,
    required this.userId,
    required this.tokenHash,
    this.deviceId,
    this.userAgent,
    required this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'tokenHash': tokenHash,
    'deviceId': deviceId,
    'userAgent': userAgent,
    'expiresAt': expiresAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory RefreshToken.fromJson(Map<String, dynamic> json) => RefreshToken(
    id: json['id'] as String,
    userId: json['userId'] as String,
    tokenHash: json['tokenHash'] as String,
    deviceId: json['deviceId'] as String?,
    userAgent: json['userAgent'] as String?,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
