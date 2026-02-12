class SharedBoardPhoto {
  final String id;
  final String pairId;
  final String uploaderId;
  final String imageUrl;
  final String? thumbnailUrl;
  final int fileSize;
  final String mimeType;
  final int? width;
  final int? height;
  /// 'direct' for photos uploaded directly to shared board,
  /// 'wallpaper' for photos that originated from wallpaper sync.
  final String sourceType;
  final DateTime createdAt;

  SharedBoardPhoto({
    required this.id,
    required this.pairId,
    required this.uploaderId,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.fileSize,
    required this.mimeType,
    this.width,
    this.height,
    this.sourceType = 'direct',
    required this.createdAt,
  });

  bool get isWallpaper => sourceType == 'wallpaper';

  factory SharedBoardPhoto.fromJson(Map<String, dynamic> json) {
    return SharedBoardPhoto(
      id: json['id'] as String,
      pairId: json['pair_id'] as String,
      uploaderId: json['uploader_id'] as String,
      imageUrl: json['image_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      fileSize: json['file_size'] as int,
      mimeType: json['mime_type'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
      sourceType: json['source_type'] as String? ?? 'direct',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pair_id': pairId,
      'uploader_id': uploaderId,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'file_size': fileSize,
      'mime_type': mimeType,
      'width': width,
      'height': height,
      'source_type': sourceType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper for local database storage
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'pair_id': pairId,
      'uploader_id': uploaderId,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'file_size': fileSize,
      'mime_type': mimeType,
      'width': width,
      'height': height,
      'source_type': sourceType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SharedBoardPhoto.fromDatabase(Map<String, dynamic> map) {
    return SharedBoardPhoto(
      id: map['id'] as String,
      pairId: map['pair_id'] as String,
      uploaderId: map['uploader_id'] as String,
      imageUrl: map['image_url'] as String,
      thumbnailUrl: map['thumbnail_url'] as String?,
      fileSize: map['file_size'] as int,
      mimeType: map['mime_type'] as String,
      width: map['width'] as int?,
      height: map['height'] as int?,
      sourceType: map['source_type'] as String? ?? 'direct',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
