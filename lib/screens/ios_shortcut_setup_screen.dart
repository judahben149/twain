import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wallpaper_sync_plugin/wallpaper_sync_plugin.dart';

/// iCloud link to the pre-built "Twain Wallpaper Sync" shortcut.
/// Replace this with your actual shared shortcut link after creating it.
const _shortcutDownloadUrl =
    'https://www.icloud.com/shortcuts/120f919edf314ef1b9f3f321b9b12580';

class IosShortcutSetupScreen extends ConsumerStatefulWidget {
  const IosShortcutSetupScreen({super.key});

  @override
  ConsumerState<IosShortcutSetupScreen> createState() =>
      _IosShortcutSetupScreenState();
}

class _IosShortcutSetupScreenState
    extends ConsumerState<IosShortcutSetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Map<String, dynamic>? _debugInfo;
  bool _loadingDebug = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeSetup() async {
    try {
      await WallpaperSyncPlugin.markShortcutSetupComplete();
    } catch (e) {
      // Best-effort — don't block the user
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Shortcuts setup complete!'),
        backgroundColor: context.twainTheme.iconColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _downloadShortcut() async {
    final url = Uri.parse(_shortcutDownloadUrl);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open the download link'),
            backgroundColor: context.twainTheme.destructiveColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open the download link'),
          backgroundColor: context.twainTheme.destructiveColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _showDebugInfo() async {
    setState(() => _loadingDebug = true);
    try {
      final info = await WallpaperSyncPlugin.getDebugInfo();
      if (!mounted) return;
      setState(() {
        _debugInfo = info;
        _loadingDebug = false;
      });
      _showDebugDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDebug = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching debug info: $e'),
          backgroundColor: context.twainTheme.destructiveColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showDebugDialog() {
    final info = _debugInfo;
    if (info == null) return;

    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'App Group Diagnostics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _debugRow(theme, 'Container Exists',
                    info['containerExists']?.toString() ?? 'unknown',
                    isGood: info['containerExists'] == true),
                _debugRow(theme, 'Container Path',
                    info['containerPath']?.toString() ?? 'null'),
                _debugRow(theme, 'Defaults Exist',
                    info['defaultsExist']?.toString() ?? 'unknown',
                    isGood: info['defaultsExist'] == true),
                _debugRow(theme, 'Wallpaper Exists',
                    info['wallpaperExists']?.toString() ?? 'unknown',
                    isGood: info['wallpaperExists'] == true),
                _debugRow(theme, 'Wallpaper Path',
                    info['wallpaperPath']?.toString() ?? 'null'),
                _debugRow(theme, 'File Size',
                    _formatFileSize(info['wallpaperFileSize'])),
                _debugRow(theme, 'Current Version',
                    info['currentVersion']?.toString() ?? 'null'),
                _debugRow(theme, 'Last Applied',
                    info['lastApplied']?.toString() ?? 'null'),
                _debugRow(theme, 'Has New Wallpaper',
                    info['hasNewWallpaper']?.toString() ?? 'unknown'),
                _debugRow(theme, 'Shortcut Setup Complete',
                    info['shortcutSetupComplete']?.toString() ?? 'unknown'),
                const SizedBox(height: 16),
                if (info['containerExists'] != true)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      'App Group container is NOT accessible. '
                      'Make sure "group.com.judahben149.twain" is added to '
                      'the App Group capability in your Apple Developer Portal '
                      'provisioning profile, then re-download the profile in Xcode.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                        height: 1.4,
                      ),
                    ),
                  )
                else if (info['wallpaperExists'] != true)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(
                      'App Group container exists but no wallpaper file found. '
                      'Try syncing a wallpaper from the wallpaper screen first, '
                      'then check again.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                        height: 1.4,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Everything looks good! The wallpaper is saved in the '
                      'App Group container and should be accessible by the Shortcut.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _debugRow(ThemeData theme, String label, String value,
      {bool? isGood}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isGood != null)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 2),
              child: Icon(
                isGood ? Icons.check_circle : Icons.error,
                size: 16,
                color: isGood ? Colors.green : Colors.red,
              ),
            ),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return 'N/A';
    final bytes = (size is int) ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openShortcuts() async {
    try {
      await WallpaperSyncPlugin.openShortcutsApp();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open Shortcuts app'),
          backgroundColor: context.twainTheme.destructiveColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpaper Shortcuts Setup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadingDebug ? null : _showDebugInfo,
            icon: _loadingDebug
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bug_report_outlined),
            tooltip: 'Diagnostics',
          ),
        ],
      ),
      body: Column(
        children: [
          // Page indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: List.generate(3, (index) {
                final isActive = index == _currentPage;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? twainTheme.iconColor
                          : theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildWhyPage(theme, twainTheme),
                _buildDownloadPage(theme, twainTheme),
                _buildAutomationPage(theme, twainTheme),
              ],
            ),
          ),

          // Navigation buttons
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: twainTheme.iconColor,
                          side: BorderSide(color: twainTheme.iconColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _currentPage == 2 ? _completeSetup : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: twainTheme.iconColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage == 2 ? 'Done' : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Page 1: Why --

  Widget _buildWhyPage(ThemeData theme, TwainThemeExtension twainTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: twainTheme.iconColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Why do I need Shortcuts?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'iOS doesn\'t allow apps to change your wallpaper directly. '
            'This is an Apple security restriction that applies to all apps.',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Apple\'s Shortcuts app bridges this gap. We\'ve built a ready-made '
            'Shortcut that you can download in one tap — then your wallpaper '
            'can update whenever your partner sends a new one.',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: twainTheme.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: twainTheme.iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'It takes less than a minute to set up!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- Page 2: Download the Shortcut --

  Widget _buildDownloadPage(ThemeData theme, TwainThemeExtension twainTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.download_rounded,
            size: 48,
            color: twainTheme.iconColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Add the Shortcut',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap the button below to download the Twain Wallpaper Sync shortcut. '
            'When prompted, tap "Add Shortcut" to save it.',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _downloadShortcut,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download Shortcut'),
              style: ElevatedButton.styleFrom(
                backgroundColor: twainTheme.iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What does this Shortcut do?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBullet(theme, 'Checks if your partner sent a new wallpaper'),
                _buildBullet(theme, 'Downloads the wallpaper from Twain'),
                _buildBullet(theme, 'Sets it as your wallpaper'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Page 3: Set up Automation (optional) --

  Widget _buildAutomationPage(ThemeData theme, TwainThemeExtension twainTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_mode,
            size: 48,
            color: twainTheme.iconColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Make it automatic',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You can run the shortcut manually anytime, but for the best experience '
            'set up an automation so it runs on its own:',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildStep(theme, twainTheme, '1',
              'Open the Shortcuts app and tap the Automation tab'),
          _buildStep(theme, twainTheme, '2',
              'Tap + and choose a trigger (e.g. "Time of Day" or when "Twain" is opened)'),
          _buildStep(theme, twainTheme, '3',
              'Search for and select "Run Shortcut", then pick "Twain Wallpaper Sync"'),
          _buildStep(theme, twainTheme, '4',
              'Turn off "Ask Before Running" so it runs automatically'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openShortcuts,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Shortcuts App'),
              style: OutlinedButton.styleFrom(
                foregroundColor: twainTheme.iconColor,
                side: BorderSide(color: twainTheme.iconColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: twainTheme.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: twainTheme.iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can skip this step and just run the shortcut manually whenever you want to apply a new wallpaper.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    ThemeData theme,
    TwainThemeExtension twainTheme,
    String number,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: twainTheme.iconColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
