class StickyNote {
  final String id;
  final String pairId;
  final String senderId;
  final String? senderName;
  final String message;
  final String color;
  final List<String> likedByUserIds;
  final int replyCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  StickyNote({
    required this.id,
    required this.pairId,
    required this.senderId,
    this.senderName,
    required this.message,
    required this.color,
    required this.likedByUserIds,
    required this.replyCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StickyNote.fromJson(Map<String, dynamic> json) {
    List<String> likedByUserIds = [];
    if (json['liked_by_user_ids'] != null) {
      if (json['liked_by_user_ids'] is List) {
        likedByUserIds = List<String>.from(json['liked_by_user_ids'] as List);
      }
    }

    return StickyNote(
      id: json['id'] as String,
      pairId: json['pair_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?,
      message: json['message'] as String,
      color: json['color'] as String? ?? 'FFF9C4', // Default yellow
      likedByUserIds: likedByUserIds,
      replyCount: json['reply_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pair_id': pairId,
      'sender_id': senderId,
      'message': message,
      'color': color,
      'liked_by_user_ids': likedByUserIds,
      'reply_count': replyCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StickyNote copyWith({
    String? id,
    String? pairId,
    String? senderId,
    String? senderName,
    String? message,
    String? color,
    List<String>? likedByUserIds,
    int? replyCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StickyNote(
      id: id ?? this.id,
      pairId: pairId ?? this.pairId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      color: color ?? this.color,
      likedByUserIds: likedByUserIds ?? this.likedByUserIds,
      replyCount: replyCount ?? this.replyCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  bool isLikedBy(String? userId) => userId != null && likedByUserIds.contains(userId);

  int get likeCount => likedByUserIds.length;

  bool get hasReplies => replyCount > 0;
}
