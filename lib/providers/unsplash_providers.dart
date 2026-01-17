import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/models/unsplash_wallpaper.dart';
import 'package:twain/services/unsplash_service.dart';

/// Provider for UnsplashService
final unsplashServiceProvider = Provider<UnsplashService>((ref) {
  return UnsplashService();
});

/// Filter types for browsing wallpapers
enum UnsplashFilter {
  random,
  editorial,
  popular,
  category,
}

String unsplashCacheKey(UnsplashFilter filter, String? category) {
  if (filter == UnsplashFilter.category) {
    return '${filter.name}_${category ?? ''}';
  }
  return filter.name;
}

/// State for Unsplash wallpaper browsing
class UnsplashState {
  final List<UnsplashWallpaper> wallpapers;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? error;
  final UnsplashFilter currentFilter;
  final String? currentCategory; // For category filter

  UnsplashState({
    this.wallpapers = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
    this.currentFilter = UnsplashFilter.editorial, // Default to Editorial
    this.currentCategory,
  });

  UnsplashState copyWith({
    List<UnsplashWallpaper>? wallpapers,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? error,
    UnsplashFilter? currentFilter,
    String? currentCategory,
  }) {
    return UnsplashState(
      wallpapers: wallpapers ?? this.wallpapers,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
      currentFilter: currentFilter ?? this.currentFilter,
      currentCategory: currentCategory ?? this.currentCategory,
    );
  }
}

/// StateNotifier for managing Unsplash wallpapers
class UnsplashNotifier extends StateNotifier<UnsplashState> {
  final UnsplashService _service;
  final Map<String, UnsplashState> _cache = {};

  UnsplashNotifier(this._service) : super(UnsplashState());

  /// Load wallpapers based on current filter
  Future<void> loadWallpapers({
    UnsplashFilter? filter,
    String? category,
    bool loadMore = false,
  }) async {
    // Prevent loading if already loading or no more results
    if (state.isLoading || (loadMore && !state.hasMore)) {
      return;
    }

    try {
      final requestedFilter = filter ?? state.currentFilter;
      final requestedCategory = requestedFilter == UnsplashFilter.category
          ? (category ?? state.currentCategory)
          : null;
      final cacheKey = unsplashCacheKey(requestedFilter, requestedCategory);

      final isNewFilter = requestedFilter != state.currentFilter;
      final isNewCategory = requestedFilter == UnsplashFilter.category &&
          requestedCategory != state.currentCategory;

      if (loadMore) {
        state = state.copyWith(isLoadingMore: true);
      } else if (isNewFilter || isNewCategory) {
        final cachedState = _cache[cacheKey];
        if (cachedState != null) {
          state = cachedState.copyWith(
            isLoading: false,
            isLoadingMore: false,
            error: null,
          );
          return;
        }

        state = UnsplashState(
          isLoading: true,
          currentFilter: requestedFilter,
          currentCategory: requestedCategory,
        );
      } else {
        state = state.copyWith(
          isLoading: true,
          error: null,
          currentFilter: requestedFilter,
          currentCategory: requestedCategory,
        );
      }

      // Fetch wallpapers based on filter
      List<UnsplashWallpaper> newWallpapers;
      final currentFilter = requestedFilter;
      final page = loadMore ? state.currentPage + 1 : 1;

      switch (currentFilter) {
        case UnsplashFilter.random:
          newWallpapers = await _service.fetchRandomWallpapers(count: 20);
          break;

        case UnsplashFilter.editorial:
          newWallpapers = await _service.fetchEditorialWallpapers(
            page: page,
            perPage: 20,
          );
          break;

        case UnsplashFilter.popular:
          newWallpapers = await _service.fetchPopularWallpapers(
            page: page,
            perPage: 20,
          );
          break;

        case UnsplashFilter.category:
          if (state.currentCategory == null) {
            throw Exception('Category not specified');
          }
          newWallpapers = await _service.searchByCategory(
            category: state.currentCategory!,
            page: page,
            perPage: 20,
          );
          break;
      }

      // Update state with new wallpapers
      final updatedWallpapers = loadMore
          ? [...state.wallpapers, ...newWallpapers]
          : newWallpapers;

      final updatedState = state.copyWith(
        wallpapers: updatedWallpapers,
        isLoading: false,
        isLoadingMore: false,
        hasMore: newWallpapers.isNotEmpty, // No more if empty response
        currentPage: page,
        error: null,
        currentFilter: requestedFilter,
        currentCategory: requestedCategory,
      );

      state = updatedState;
      _cache[cacheKey] = updatedState;
    } catch (e) {
      print('Error loading wallpapers: $e');
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Switch to a different filter
  Future<void> switchFilter(UnsplashFilter filter) async {
    await loadWallpapers(filter: filter);
  }

  /// Search by category
  Future<void> searchCategory(String category) async {
    await loadWallpapers(
      filter: UnsplashFilter.category,
      category: category,
    );
  }

  /// Load more wallpapers (for infinite scroll)
  Future<void> loadMore() async {
    await loadWallpapers(loadMore: true);
  }

  /// Reset state (clear wallpapers and errors)
  void reset() {
    _cache.clear();
    state = UnsplashState();
  }

  /// Trigger download tracking for Unsplash attribution
  Future<void> trackDownload(UnsplashWallpaper wallpaper) async {
    await _service.triggerDownload(wallpaper.downloadLocation);
  }
}

/// Provider for UnsplashNotifier
final unsplashProvider =
    StateNotifierProvider<UnsplashNotifier, UnsplashState>((ref) {
  final service = ref.watch(unsplashServiceProvider);
  return UnsplashNotifier(service);
});
