/// Model representing a wallpaper rotation folder
/// Folders are shared between paired users and can contain up to 30 images
class WallpaperFolder {
  final String id;
  final String pairId;
  final String name;
  final String createdBy;

  // Rotation settings
  final bool isActive;
  final int rotationIntervalValue;
  final String rotationIntervalUnit; // 'minutes', 'hours', 'days'
  final String rotationOrder; // 'sequential', 'random'

  // Rotation state
  final int currentIndex;
  final DateTime? lastRotatedAt;
  final DateTime? nextRotationAt;

  // Metadata
  final int imageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  WallpaperFolder({
    required this.id,
    required this.pairId,
    required this.name,
    required this.createdBy,
    required this.isActive,
    required this.rotationIntervalValue,
    required this.rotationIntervalUnit,
    required this.rotationOrder,
    required this.currentIndex,
    this.lastRotatedAt,
    this.nextRotationAt,
    required this.imageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parse Supabase JSON response to model
  factory WallpaperFolder.fromJson(Map<String, dynamic> json) {
    return WallpaperFolder(
      id: json['id'] as String,
      pairId: json['pair_id'] as String,
      name: json['name'] as String,
      createdBy: json['created_by'] as String,
      isActive: json['is_active'] as bool,
      rotationIntervalValue: json['rotation_interval_value'] as int,
      rotationIntervalUnit: json['rotation_interval_unit'] as String,
      rotationOrder: json['rotation_order'] as String,
      currentIndex: json['current_index'] as int,
      lastRotatedAt: json['last_rotated_at'] != null
          ? DateTime.parse(json['last_rotated_at'] as String)
          : null,
      nextRotationAt: json['next_rotation_at'] != null
          ? DateTime.parse(json['next_rotation_at'] as String)
          : null,
      imageCount: json['image_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON (for database operations)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pair_id': pairId,
      'name': name,
      'created_by': createdBy,
      'is_active': isActive,
      'rotation_interval_value': rotationIntervalValue,
      'rotation_interval_unit': rotationIntervalUnit,
      'rotation_order': rotationOrder,
      'current_index': currentIndex,
      'last_rotated_at': lastRotatedAt?.toIso8601String(),
      'next_rotation_at': nextRotationAt?.toIso8601String(),
      'image_count': imageCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get human-readable rotation interval
  String get rotationIntervalDisplay {
    final unit = rotationIntervalValue == 1
        ? rotationIntervalUnit.substring(0, rotationIntervalUnit.length - 1)
        : rotationIntervalUnit;
    return '$rotationIntervalValue $unit';
  }

  /// Check if folder can accept more images
  bool get canAddImages => imageCount < 30;

  /// Get time until next rotation
  Duration? get timeUntilNextRotation {
    if (nextRotationAt == null) return null;
    final now = DateTime.now();
    if (nextRotationAt!.isBefore(now)) return Duration.zero;
    return nextRotationAt!.difference(now);
  }

  /// Get friendly status text
  String get statusText {
    if (!isActive) return 'Inactive';
    if (imageCount == 0) return 'No images';

    final remaining = timeUntilNextRotation;
    if (remaining == null) return 'Ready';
    if (remaining == Duration.zero) return 'Rotating now...';

    // Format remaining time
    if (remaining.inDays > 0) {
      return 'Next in ${remaining.inDays}d ${remaining.inHours % 24}h';
    } else if (remaining.inHours > 0) {
      return 'Next in ${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else {
      return 'Next in ${remaining.inMinutes}m';
    }
  }

  WallpaperFolder copyWith({
    String? id,
    String? pairId,
    String? name,
    String? createdBy,
    bool? isActive,
    int? rotationIntervalValue,
    String? rotationIntervalUnit,
    String? rotationOrder,
    int? currentIndex,
    DateTime? lastRotatedAt,
    DateTime? nextRotationAt,
    int? imageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WallpaperFolder(
      id: id ?? this.id,
      pairId: pairId ?? this.pairId,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      rotationIntervalValue: rotationIntervalValue ?? this.rotationIntervalValue,
      rotationIntervalUnit: rotationIntervalUnit ?? this.rotationIntervalUnit,
      rotationOrder: rotationOrder ?? this.rotationOrder,
      currentIndex: currentIndex ?? this.currentIndex,
      lastRotatedAt: lastRotatedAt ?? this.lastRotatedAt,
      nextRotationAt: nextRotationAt ?? this.nextRotationAt,
      imageCount: imageCount ?? this.imageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'WallpaperFolder(id: $id, name: $name, imageCount: $imageCount, isActive: $isActive)';
  }
}
