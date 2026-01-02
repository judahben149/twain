import 'package:flutter/material.dart';

/// Avatar style configuration
class AvatarStyle {
  final String id;
  final String displayName;
  final IconData icon;
  final String description;

  const AvatarStyle({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.description,
  });
}

/// Constants for Dicebear avatar configuration
class AvatarConstants {
  // Feature flag for gender filtering (future enhancement)
  static const bool genderFilterEnabled = false;

  // Available avatar styles
  static const List<AvatarStyle> styles = [
    AvatarStyle(
      id: 'bottts',
      displayName: 'Bottts',
      icon: Icons.smart_toy,
      description: 'Robot-themed avatars',
    ),
    AvatarStyle(
      id: 'croodles',
      displayName: 'Croodles',
      icon: Icons.brush,
      description: 'Hand-drawn doodle avatars',
    ),
    AvatarStyle(
      id: 'avataaars',
      displayName: 'Avataaars',
      icon: Icons.face,
      description: 'Cartoon-style human avatars',
    ),
    AvatarStyle(
      id: 'adventurer',
      displayName: 'Adventurer',
      icon: Icons.explore,
      description: 'Adventure-themed avatars',
    ),
    AvatarStyle(
      id: 'open-peeps',
      displayName: 'Open Peeps',
      icon: Icons.people,
      description: 'Diverse human illustrations',
    ),
  ];

  // Consistent seeds for avatar generation (10 per style)
  static const List<String> seeds = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
  ];

  // Future: Gender-specific seeds (when gender field is added)
  // static const Map<String, List<String>> genderSeeds = {
  //   'all': ['neutral-1', 'neutral-2', ...],
  //   'male': ['male-1', 'male-2', ...],
  //   'female': ['female-1', 'female-2', ...],
  // };

  // Dicebear API base URL
  static const String dicebearBaseUrl = 'https://api.dicebear.com/7.x';
}
