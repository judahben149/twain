import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:twain/constants/app_themes.dart';
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

    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Browse Wallpapers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: twainTheme.cardBackgroundColor,
        elevation: context.isDarkMode ? 0 : 1,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(context, state),
          Expanded(
            child: _buildContent(state),
          ),
        ],
      ),
    );
  }

  /// Build filter chips (Editorial, Popular, Categories, Random)
  Widget _buildFilterChips(BuildContext context, UnsplashState state) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return Container(
      color: twainTheme.cardBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
        border: context.isDarkMode
            ? Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5))
            : null,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              context,
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
              context,
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
              context,
              label: _selectedCategory ?? 'Categories',
              isSelected: state.currentFilter == UnsplashFilter.category,
              onTap: _showCategorySheet,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context,
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
  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? twainTheme.iconColor
              : twainTheme.iconBackgroundColor,
          border: Border.all(color: twainTheme.iconColor, width: 1.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected || context.isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  /// Build category selection bottom sheet
  Widget _buildCategorySheet() {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Category',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
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
                        ? twainTheme.iconColor
                        : twainTheme.iconBackgroundColor,
                    border: Border.all(
                      color: twainTheme.iconColor,
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
                          : theme.colorScheme.onSurface.withOpacity(0.7),
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
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    // Initial loading
    if (state.isLoading && state.wallpapers.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: twainTheme.iconColor,
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
      color: twainTheme.iconColor,
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
          childAspectRatio: 0.7, // Fallback ratio, overridden by AspectRatio widget
        ),
        itemCount:
            state.wallpapers.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at bottom while loading more
          if (index == state.wallpapers.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: twainTheme.iconColor,
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
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    // Calculate aspect ratio from image dimensions
    final aspectRatio = wallpaper.height > 0
        ? wallpaper.width / wallpaper.height
        : 0.7; // Fallback for portrait

    return GestureDetector(
      onTap: () => _onWallpaperTap(wallpaper),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: context.isDarkMode
                ? null
                : [
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
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: twainTheme.iconColor,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
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
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load wallpapers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
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
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(unsplashProvider.notifier).loadWallpapers();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: twainTheme.iconColor,
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No wallpapers found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different filter or category',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
