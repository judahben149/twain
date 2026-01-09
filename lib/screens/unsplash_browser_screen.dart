import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/models/unsplash_wallpaper.dart';
import 'package:twain/providers/unsplash_providers.dart';
import 'package:twain/screens/wallpaper_preview_screen.dart';

class UnsplashBrowserScreen extends ConsumerStatefulWidget {
  const UnsplashBrowserScreen({super.key});

  @override
  ConsumerState<UnsplashBrowserScreen> createState() =>
      _UnsplashBrowserScreenState();
}

class _UnsplashBrowserScreenState
    extends ConsumerState<UnsplashBrowserScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedCategory;

  // Available categories for filtering
  final List<Map<String, String>> _categories = [
    {'label': 'Nature', 'query': 'nature wallpaper'},
    {'label': 'Abstract', 'query': 'abstract wallpaper'},
    {'label': 'Minimal', 'query': 'minimal wallpaper'},
    {'label': 'Architecture', 'query': 'architecture wallpaper'},
    {'label': 'Animals', 'query': 'animals wallpaper'},
    {'label': 'Food', 'query': 'food wallpaper'},
    {'label': 'Travel', 'query': 'travel wallpaper'},
    {'label': 'Art', 'query': 'art wallpaper'},
    {'label': 'Textures', 'query': 'texture wallpaper'},
    {'label': 'Colors', 'query': 'colorful wallpaper'},
  ];

  @override
  void initState() {
    super.initState();

    // Load initial wallpapers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(unsplashProvider.notifier).loadWallpapers();
    });

    // Setup infinite scroll listener
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Handle scroll for infinite loading
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      // Load more when user is near bottom (90% scrolled)
      ref.read(unsplashProvider.notifier).loadMore();
    }
  }

  /// Show category selection bottom sheet
  void _showCategorySheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildCategorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(unsplashProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Browse Wallpapers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(state),
          Expanded(
            child: _buildContent(state),
          ),
        ],
      ),
    );
  }

  /// Build filter chips (Editorial, Popular, Categories, Random)
  Widget _buildFilterChips(UnsplashState state) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'Editorial',
              isSelected: state.currentFilter == UnsplashFilter.editorial,
              onTap: () {
                setState(() => _selectedCategory = null);
                ref
                    .read(unsplashProvider.notifier)
                    .switchFilter(UnsplashFilter.editorial);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Popular',
              isSelected: state.currentFilter == UnsplashFilter.popular,
              onTap: () {
                setState(() => _selectedCategory = null);
                ref
                    .read(unsplashProvider.notifier)
                    .switchFilter(UnsplashFilter.popular);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: _selectedCategory ?? 'Categories',
              isSelected: state.currentFilter == UnsplashFilter.category,
              onTap: _showCategorySheet,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Random',
              isSelected: state.currentFilter == UnsplashFilter.random,
              onTap: () {
                setState(() => _selectedCategory = null);
                ref
                    .read(unsplashProvider.notifier)
                    .switchFilter(UnsplashFilter.random);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual filter chip
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE91E63) : Colors.white,
          border: Border.all(
            color:
                isSelected ? const Color(0xFFE91E63) : const Color(0xFFE91E63),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFFE91E63),
          ),
        ),
      ),
    );
  }

  /// Build category selection bottom sheet
  Widget _buildCategorySheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Category',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _categories.map((category) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedCategory = category['label']);
                  ref
                      .read(unsplashProvider.notifier)
                      .searchCategory(category['query']!);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedCategory == category['label']
                        ? const Color(0xFFE91E63)
                        : Colors.white,
                    border: Border.all(
                      color: const Color(0xFFE91E63),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category['label']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedCategory == category['label']
                          ? Colors.white
                          : const Color(0xFFE91E63),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Build main content (grid, loading, error, empty states)
  Widget _buildContent(UnsplashState state) {
    // Initial loading
    if (state.isLoading && state.wallpapers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE91E63),
        ),
      );
    }

    // Error state
    if (state.error != null && state.wallpapers.isEmpty) {
      return _buildErrorState(state.error!);
    }

    // Empty state
    if (state.wallpapers.isEmpty) {
      return _buildEmptyState();
    }

    // Wallpaper grid
    return RefreshIndicator(
      color: const Color(0xFFE91E63),
      onRefresh: () async {
        await ref.read(unsplashProvider.notifier).loadWallpapers();
      },
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 9 / 16, // Portrait aspect ratio for wallpapers
        ),
        itemCount:
            state.wallpapers.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at bottom while loading more
          if (index == state.wallpapers.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: Color(0xFFE91E63),
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final wallpaper = state.wallpapers[index];
          return _buildWallpaperCard(wallpaper);
        },
      ),
    );
  }

  /// Build wallpaper card in grid
  Widget _buildWallpaperCard(UnsplashWallpaper wallpaper) {
    return GestureDetector(
      onTap: () => _onWallpaperTap(wallpaper),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: wallpaper.smallUrl, // Use small (~400px) for better quality
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE91E63),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              // Quality badge (HD/4K)
              if (wallpaper.qualityBadge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      wallpaper.qualityBadge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle wallpaper tap - navigate to preview
  void _onWallpaperTap(UnsplashWallpaper wallpaper) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WallpaperPreviewScreen(
          imageUrl: wallpaper.regularUrl, // Use regular quality for preview
          unsplashWallpaper: wallpaper, // Pass for download tracking
        ),
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load wallpapers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.contains('Rate limit')
                  ? 'Too many requests. Please try again later.'
                  : 'Check your internet connection and try again.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(unsplashProvider.notifier).loadWallpapers();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No wallpapers found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different filter or category',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
