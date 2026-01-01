class StickyNote {
  final String id;
  final String pairId;
  final String senderId;
  final String? senderName;
  final String message;
  final bool isLiked;
  final DateTime createdAt;
  final DateTime updatedAt;

  StickyNote({
    required this.id,
    required this.pairId,
    required this.senderId,
    this.senderName,
    required this.message,
    required this.isLiked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StickyNote.fromJson(Map<String, dynamic> json) {
    return StickyNote(
      id: json['id'] as String,
      pairId: json['pair_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?,
      message: json['message'] as String,
      isLiked: json['is_liked'] as bool? ?? false,
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
      'is_liked': isLiked,
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
    bool? isLiked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StickyNote(
      id: id ?? this.id,
      pairId: pairId ?? this.pairId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
