import 'package:flutter_cache_manager/flutter_cache_manager.dart';

enum TwainCacheBucket {
  wallpaperImages,
  avatarImages,
  sharedBoardThumbnails,
}

class TwainCacheManagers {
  TwainCacheManagers._();

  static final Map<TwainCacheBucket, CacheManager> _cacheManagers = {};

  static CacheManager getManager(TwainCacheBucket bucket) {
    return _cacheManagers.putIfAbsent(bucket, () {
      switch (bucket) {
        case TwainCacheBucket.wallpaperImages:
          return CacheManager(
            Config(
              'twain_wallpaper_images',
              stalePeriod: const Duration(days: 14),
              maxNrOfCacheObjects: 150,
            ),
          );
        case TwainCacheBucket.avatarImages:
          return CacheManager(
            Config(
              'twain_avatar_images',
              stalePeriod: const Duration(days: 30),
              maxNrOfCacheObjects: 200,
            ),
          );
        case TwainCacheBucket.sharedBoardThumbnails:
          return CacheManager(
            Config(
              'twain_shared_board_thumbs',
              stalePeriod: const Duration(days: 7),
              maxNrOfCacheObjects: 120,
            ),
          );
      }
    });
  }
}
