class Wallpaper {
  final String id;
  final String pairId;
  final String senderId;
  final String imageUrl;
  final String sourceType; // 'shared_board' or 'device_gallery'
  final String applyTo; // 'partner' or 'both'
  final String status; // 'pending', 'applied', 'failed'
  final DateTime? appliedAt;
  final DateTime createdAt;

  Wallpaper({
    required this.id,
    required this.pairId,
    required this.senderId,
    required this.imageUrl,
    required this.sourceType,
    required this.applyTo,
    required this.status,
    this.appliedAt,
    required this.createdAt,
  });

  factory Wallpaper.fromJson(Map<String, dynamic> json) {
    return Wallpaper(
      id: json['id'] as String,
      pairId: json['pair_id'] as String,
      senderId: json['sender_id'] as String,
      imageUrl: json['image_url'] as String,
      sourceType: json['source_type'] as String,
      applyTo: json['apply_to'] as String,
      status: json['status'] as String,
      appliedAt: json['applied_at'] != null
          ? DateTime.parse(json['applied_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pair_id': pairId,
      'sender_id': senderId,
      'image_url': imageUrl,
      'source_type': sourceType,
      'apply_to': applyTo,
      'status': status,
      'applied_at': appliedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper for local database storage
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'pair_id': pairId,
      'sender_id': senderId,
      'image_url': imageUrl,
      'source_type': sourceType,
      'apply_to': applyTo,
      'status': status,
      'applied_at': appliedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Wallpaper.fromDatabase(Map<String, dynamic> map) {
    return Wallpaper(
      id: map['id'] as String,
      pairId: map['pair_id'] as String,
      senderId: map['sender_id'] as String,
      imageUrl: map['image_url'] as String,
      sourceType: map['source_type'] as String,
      applyTo: map['apply_to'] as String,
      status: map['status'] as String,
      appliedAt: map['applied_at'] != null
          ? DateTime.parse(map['applied_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
