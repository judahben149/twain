/// Model representing an image within a wallpaper folder
/// Images can come from Shared Board, Device Gallery, or Unsplash
class FolderImage {
  final String id;
  final String folderId;

  // Image source
  final String imageUrl;
  final String sourceType; // 'shared_board', 'device_gallery', 'unsplash'
  final String? sourceId; // References original photo if from shared_board

  // Unsplash attribution metadata
  final String? unsplashPhotographerName;
  final String? unsplashPhotographerUsername;
  final String? unsplashDownloadLocation;

  // Ordering
  final int position; // 0-based index for sequential rotation

  // Image metadata
  final String? thumbnailUrl;
  final int? width;
  final int? height;

  // Metadata
  final String addedBy;
  final DateTime createdAt;

  FolderImage({
    required this.id,
    required this.folderId,
    required this.imageUrl,
    required this.sourceType,
    this.sourceId,
    this.unsplashPhotographerName,
    this.unsplashPhotographerUsername,
    this.unsplashDownloadLocation,
    required this.position,
    this.thumbnailUrl,
    this.width,
    this.height,
    required this.addedBy,
    required this.createdAt,
  });

  /// Parse Supabase JSON response to model
  factory FolderImage.fromJson(Map<String, dynamic> json) {
    return FolderImage(
      id: json['id'] as String,
      folderId: json['folder_id'] as String,
      imageUrl: json['image_url'] as String,
      sourceType: json['source_type'] as String,
      sourceId: json['source_id'] as String?,
      unsplashPhotographerName: json['unsplash_photographer_name'] as String?,
      unsplashPhotographerUsername:
          json['unsplash_photographer_username'] as String?,
      unsplashDownloadLocation: json['unsplash_download_location'] as String?,
      position: json['position'] as int,
      thumbnailUrl: json['thumbnail_url'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      addedBy: json['added_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to JSON (for database operations)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'folder_id': folderId,
      'image_url': imageUrl,
      'source_type': sourceType,
      'source_id': sourceId,
      'unsplash_photographer_name': unsplashPhotographerName,
      'unsplash_photographer_username': unsplashPhotographerUsername,
      'unsplash_download_location': unsplashDownloadLocation,
      'position': position,
      'thumbnail_url': thumbnailUrl,
      'width': width,
      'height': height,
      'added_by': addedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Calculate aspect ratio for display
  double? get aspectRatio {
    if (width != null && height != null && height! > 0) {
      return width! / height!;
    }
    return null;
  }

  /// Get display URL (thumbnail if available, otherwise full image)
  String get displayUrl => thumbnailUrl ?? imageUrl;

  /// Check if image is from Unsplash
  bool get isFromUnsplash => sourceType == 'unsplash';

  /// Get source label for UI
  String get sourceLabel {
    switch (sourceType) {
      case 'shared_board':
        return 'Shared Board';
      case 'device_gallery':
        return 'Device';
      case 'unsplash':
        return 'Unsplash';
      default:
        return 'Unknown';
    }
  }

  /// Get attribution text for Unsplash images
  String? get attributionText {
    if (!isFromUnsplash || unsplashPhotographerName == null) return null;
    return 'Photo by $unsplashPhotographerName';
  }

  FolderImage copyWith({
    String? id,
    String? folderId,
    String? imageUrl,
    String? sourceType,
    String? sourceId,
    String? unsplashPhotographerName,
    String? unsplashPhotographerUsername,
    String? unsplashDownloadLocation,
    int? position,
    String? thumbnailUrl,
    int? width,
    int? height,
    String? addedBy,
    DateTime? createdAt,
  }) {
    return FolderImage(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      unsplashPhotographerName:
          unsplashPhotographerName ?? this.unsplashPhotographerName,
      unsplashPhotographerUsername:
          unsplashPhotographerUsername ?? this.unsplashPhotographerUsername,
      unsplashDownloadLocation:
          unsplashDownloadLocation ?? this.unsplashDownloadLocation,
      position: position ?? this.position,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      width: width ?? this.width,
      height: height ?? this.height,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'FolderImage(id: $id, position: $position, sourceType: $sourceType)';
  }
}
