
class TwainUser {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? pairId;
  final String? fcmToken;
  final String? deviceId;
  final String? status;
  final DateTime? lastActiveAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? preferences;
  final Map<String, dynamic>? metaData;

  TwainUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.pairId,
    this.fcmToken,
    this.deviceId,
    this.status,
    this.lastActiveAt,
    required this.createdAt,
    required this.updatedAt,
    this.preferences,
    this.metaData,
  });

  factory TwainUser.fromJson(Map<String, dynamic> json) {
    return TwainUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      pairId: json['pair_id'] as String?,
      fcmToken: json['fcm_token'] as String?,
      deviceId: json['device_id'] as String?,
      status: json['status'] as String?,
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      preferences: json['preferences'] as Map<String, dynamic>?,
      metaData: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'pair_id': pairId,
      'fcm_token': fcmToken,
      'device_id': deviceId,
      'status': status,
      'last_active_at': lastActiveAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'preferences': preferences,
      'metadata': metaData,
    };
  }

  TwainUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? pairId,
    String? fcmToken,
    String? deviceId,
    String? status,
    DateTime? lastActiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? metaData,
  }) {
    return TwainUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      pairId: pairId ?? this.pairId,
      fcmToken: fcmToken ?? this.fcmToken,
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferences: preferences ?? this.preferences,
      metaData: metaData ?? this.metaData,
    );
  }
}
