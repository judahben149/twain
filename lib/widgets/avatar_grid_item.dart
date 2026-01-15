import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:twain/services/avatar_service.dart';
import 'package:twain/services/cache/twain_cache_managers.dart';

/// Individual avatar tile in the grid
class AvatarGridItem extends StatelessWidget {
  final AvatarOption avatar;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  const AvatarGridItem({
    super.key,
    required this.avatar,
    required this.onTap,
    this.isSelected = false,
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: const Color(0xFF9C27B0),
                  width: 3,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: FutureBuilder<FileInfo?>(
            future: TwainCacheManagers
                .getManager(TwainCacheBucket.avatarImages)
                .getFileFromCache(avatar.url),
            builder: (context, cacheSnapshot) {
              if (cacheSnapshot.connectionState == ConnectionState.done) {
                // If we have cached file, use it
                if (cacheSnapshot.hasData && cacheSnapshot.data != null) {
                  return SvgPicture.file(
                    cacheSnapshot.data!.file,
                    fit: BoxFit.cover,
                    placeholderBuilder: (context) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                    ),
                  );
                }
              }

              // Otherwise, load from network and cache
              return FutureBuilder(
                future: TwainCacheManagers
                    .getManager(TwainCacheBucket.avatarImages)
                    .downloadFile(avatar.url),
                builder: (context, downloadSnapshot) {
                  if (downloadSnapshot.connectionState == ConnectionState.done &&
                      downloadSnapshot.hasData) {
                    return SvgPicture.file(
                      downloadSnapshot.data!.file,
                      fit: BoxFit.cover,
                      placeholderBuilder: (context) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF9C27B0),
                          ),
                        ),
                      ),
                    );
                  }

                  // Show placeholder while loading
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF9C27B0),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
