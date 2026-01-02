import 'package:twain/constants/avatar_constants.dart';

/// Represents a single avatar option
class AvatarOption {
  final String style;
  final String seed;
  final String url;
  final String? gender;

  AvatarOption({
    required this.style,
    required this.seed,
    String? gender,
  })  : gender = gender,
        url = AvatarService.generateUrl(
          style: style,
          seed: seed,
          gender: gender,
        );
}

/// Service for managing Dicebear avatars
class AvatarService {
  /// Generate Dicebear avatar URL
  static String generateUrl({
    required String style,
    required String seed,
    String? gender,
  }) {
    var url = '${AvatarConstants.dicebearBaseUrl}/$style/svg?seed=$seed';

    // Add gender parameter if enabled and provided
    if (AvatarConstants.genderFilterEnabled && gender != null) {
      url += '&gender=$gender';
    }

    return url;
  }

  /// Get all avatar options (50 total: 5 styles × 10 seeds)
  static List<AvatarOption> getAllAvatars({String? gender}) {
    final options = <AvatarOption>[];

    for (final style in AvatarConstants.styles) {
      for (final seed in AvatarConstants.seeds) {
        options.add(AvatarOption(
          style: style.id,
          seed: seed,
          gender: gender,
        ));
      }
    }

    return options;
  }

  /// Get avatars grouped by style
  static Map<AvatarStyle, List<AvatarOption>> getAvatarsByStyle({
    String? gender,
  }) {
    final grouped = <AvatarStyle, List<AvatarOption>>{};

    for (final style in AvatarConstants.styles) {
      final styleOptions = <AvatarOption>[];

      for (final seed in AvatarConstants.seeds) {
        styleOptions.add(AvatarOption(
          style: style.id,
          seed: seed,
          gender: gender,
        ));
      }

      grouped[style] = styleOptions;
    }

    return grouped;
  }
}
