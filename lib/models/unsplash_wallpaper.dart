/// Model representing an Unsplash wallpaper
/// Maps to Unsplash API photo response
class UnsplashWallpaper {
  final String id;
  final String regularUrl; // ~1080px width (for preview)
  final String fullUrl; // Original full resolution (for download)
  final String smallUrl; // Medium quality ~400px (for grid)
  final String thumbUrl; // Small thumbnail ~200px (backup)
  final int width;
  final int height;
  final String? description;
  final String photographerName;
  final String photographerUsername;
  final String? downloadLocation; // For tracking downloads per Unsplash API guidelines

  UnsplashWallpaper({
    required this.id,
    required this.regularUrl,
    required this.fullUrl,
    required this.smallUrl,
    required this.thumbUrl,
    required this.width,
    required this.height,
    this.description,
    required this.photographerName,
    required this.photographerUsername,
    this.downloadLocation,
  });

  /// Check if image is HD quality (1920x1080 or higher)
  bool get isHD => width >= 1920 && height >= 1080;

  /// Check if image is 4K quality (3840x2160 or higher)
  bool get is4K => width >= 3840 && height >= 2160;

  /// Get quality badge label
  String? get qualityBadge {
    if (is4K) return '4K';
    if (isHD) return 'HD';
    return null;
  }

  /// Parse Unsplash API JSON response to model
  factory UnsplashWallpaper.fromJson(Map<String, dynamic> json) {
    // Extract URLs from nested object
    final urls = json['urls'] as Map<String, dynamic>;

    // Extract user details from nested object
    final user = json['user'] as Map<String, dynamic>;

    // Extract download location for attribution
    final links = json['links'] as Map<String, dynamic>?;

    return UnsplashWallpaper(
      id: json['id'] as String,
      regularUrl: urls['regular'] as String, // ~1080px
      fullUrl: urls['full'] as String, // Full resolution
      smallUrl: urls['small'] as String, // ~400px (better quality for grid)
      thumbUrl: urls['thumb'] as String, // ~200px thumbnail
      width: json['width'] as int,
      height: json['height'] as int,
      description: json['description'] as String? ??
          json['alt_description'] as String?,
      photographerName: user['name'] as String,
      photographerUsername: user['username'] as String,
      downloadLocation: links?['download_location'] as String?,
    );
  }

  /// Convert to JSON (for local storage/caching if needed)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'urls': {
        'regular': regularUrl,
        'full': fullUrl,
        'small': smallUrl,
        'thumb': thumbUrl,
      },
      'width': width,
      'height': height,
      'description': description,
      'user': {
        'name': photographerName,
        'username': photographerUsername,
      },
      'links': {
        'download_location': downloadLocation,
      },
    };
  }

  @override
  String toString() {
    return 'UnsplashWallpaper(id: $id, photographer: $photographerName, '
        'resolution: ${width}x$height)';
  }
}
