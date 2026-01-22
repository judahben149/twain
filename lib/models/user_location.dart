class UserLocation {
  final String id;
  final String userId;
  final String pairId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime recordedAt;
  final DateTime createdAt;

  const UserLocation({
    required this.id,
    required this.userId,
    required this.pairId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.recordedAt,
    required this.createdAt,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      pairId: json['pair_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      createdAt: DateTime.parse(
        (json['created_at'] ?? json['recorded_at']) as String,
      ),
    );
  }

  factory UserLocation.fromDatabase(Map<String, dynamic> map) {
    return UserLocation(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      pairId: map['pair_id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pair_id': pairId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'recorded_at': recordedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'user_id': userId,
      'pair_id': pairId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'recorded_at': recordedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserLocation copyWith({
    String? id,
    String? userId,
    String? pairId,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? recordedAt,
    DateTime? createdAt,
  }) {
    return UserLocation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      pairId: pairId ?? this.pairId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      recordedAt: recordedAt ?? this.recordedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isStale {
    final age = DateTime.now().difference(recordedAt);
    return age > const Duration(minutes: 30);
  }
}
