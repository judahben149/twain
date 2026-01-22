import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/app_theme_mode.dart';
import 'package:twain/models/wallpaper_folder.dart';
import 'package:twain/providers/folder_providers.dart';
import 'package:twain/providers/theme_providers.dart';
import 'package:twain/screens/create_folder_screen.dart';
import 'package:twain/screens/folder_detail_screen.dart';
import 'package:twain/widgets/countdown_timer.dart';

class FoldersListScreen extends ConsumerWidget {
  const FoldersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final isLight = !context.isDarkMode;
    final appThemeMode = ref.watch(themeModeProvider);
    final isMidnight = appThemeMode == AppThemeMode.amoled;
    final scaffoldColor = isLight
        ? Color.alphaBlend(
            twainTheme.iconColor.withOpacity(0.05),
            theme.colorScheme.surface,
          )
        : (isMidnight ? AppColors.backgroundAmoled : theme.colorScheme.surface);
    final foldersAsync = ref.watch(foldersStreamProvider);

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text(
          'Wallpaper Folders',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: twainTheme.cardBackgroundColor,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: foldersAsync.when(
        data: (folders) => folders.isEmpty
            ? _buildEmptyState(context, theme, twainTheme)
            : _buildFoldersList(context, folders, theme, twainTheme),
        loading: () => Center(
          child: CircularProgressIndicator(
            color: twainTheme.iconColor,
          ),
        ),
        error: (error, stack) => _buildErrorState(context, error.toString(), theme),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreateFolder(context),
        backgroundColor: twainTheme.iconColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Folder',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFoldersList(BuildContext context, List<WallpaperFolder> folders,
      ThemeData theme, TwainThemeExtension twainTheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return _buildFolderCard(context, folder, theme, twainTheme);
      },
    );
  }

  Widget _buildFolderCard(BuildContext context, WallpaperFolder folder,
      ThemeData theme, TwainThemeExtension twainTheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: twainTheme.cardBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: context.isDarkMode
            ? BorderSide(color: theme.dividerColor, width: 0.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _navigateToFolderDetail(context, folder.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: name and status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      folder.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  _buildStatusBadge(folder, twainTheme),
                ],
              ),
              const SizedBox(height: 8),

              // Image count and rotation info
              Row(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${folder.imageCount}/30 images',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    folder.rotationOrder == 'sequential'
                        ? Icons.repeat
                        : Icons.shuffle,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    folder.rotationOrder == 'sequential'
                        ? 'Sequential'
                        : 'Random',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Rotation interval
              Text(
                'Rotates every ${folder.rotationIntervalDisplay}',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),

              // Next rotation time (if active)
              if (folder.isActive && folder.nextRotationAt != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: twainTheme.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: twainTheme.iconColor,
                      ),
                      const SizedBox(width: 4),
                      CountdownTimer(
                        targetTime: folder.nextRotationAt,
                        style: TextStyle(
                          fontSize: 12,
                          color: twainTheme.iconColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(WallpaperFolder folder, TwainThemeExtension twainTheme) {
    final isActive = folder.isActive && folder.imageCount > 0;
    final color = isActive ? twainTheme.activeStatusColor : Colors.grey;
    final textColor = isActive ? twainTheme.activeStatusTextColor : Colors.grey;
    final text = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, TwainThemeExtension twainTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 80,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Folders Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a folder to automatically rotate wallpapers',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToCreateFolder(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Folder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: twainTheme.iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, ThemeData theme) {
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
              'Failed to load folders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
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

  void _navigateToCreateFolder(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateFolderScreen(),
      ),
    );
  }

  void _navigateToFolderDetail(BuildContext context, String folderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderDetailScreen(folderId: folderId),
      ),
    );
  }
}
