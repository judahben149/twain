class StickyNoteReply {
  final String id;
  final String noteId;
  final String senderId;
  final String? senderName;
  final String message;
  final DateTime createdAt;
  final DateTime updatedAt;

  StickyNoteReply({
    required this.id,
    required this.noteId,
    required this.senderId,
    this.senderName,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StickyNoteReply.fromJson(Map<String, dynamic> json) {
    return StickyNoteReply(
      id: json['id'] as String,
      noteId: json['note_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note_id': noteId,
      'sender_id': senderId,
      'sender_name': senderName,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StickyNoteReply copyWith({
    String? id,
    String? noteId,
    String? senderId,
    String? senderName,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StickyNoteReply(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
