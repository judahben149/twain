class ContentReport {
  final String id;
  final String contentType;
  final String contentId;
  final String reporterId;
  final String reason;
  final String? description;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  ContentReport({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.reporterId,
    required this.reason,
    this.description,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory ContentReport.fromJson(Map<String, dynamic> json) {
    return ContentReport(
      id: json['id'] as String,
      contentType: json['content_type'] as String,
      contentId: json['content_id'] as String,
      reporterId: json['reporter_id'] as String,
      reason: json['reason'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewedBy: json['reviewed_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_type': contentType,
      'content_id': contentId,
      'reporter_id': reporterId,
      'reason': reason,
      'description': description,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
    };
  }
}

enum ReportReason {
  inappropriate,
  spam,
  other;

  String get displayName {
    switch (this) {
      case ReportReason.inappropriate:
        return 'Inappropriate content';
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.other:
        return 'Other';
    }
  }

  String get value {
    switch (this) {
      case ReportReason.inappropriate:
        return 'inappropriate';
      case ReportReason.spam:
        return 'spam';
      case ReportReason.other:
        return 'other';
    }
  }
}

enum ContentType {
  stickyNote,
  stickyNoteReply;

  String get value {
    switch (this) {
      case ContentType.stickyNote:
        return 'sticky_note';
      case ContentType.stickyNoteReply:
        return 'sticky_note_reply';
    }
  }
}
