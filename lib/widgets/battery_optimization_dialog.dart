import 'package:flutter/material.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/services/battery_optimization_service.dart';

/// A dialog that prompts users to disable battery optimization for reliable
/// background wallpaper sync. Styled to match the app's theme.
class BatteryOptimizationDialog extends StatelessWidget {
  const BatteryOptimizationDialog({super.key});

  /// Shows the battery optimization dialog.
  /// Returns true if user enabled optimization, false if dismissed, null if skipped.
  static Future<bool?> show(BuildContext context) async {
    // Don't show on non-Android or if already optimized
    if (!BatteryOptimizationService.isAndroid) return null;

    final shouldShow = await BatteryOptimizationService.shouldShowDialog();
    if (!shouldShow) return null;

    if (!context.mounted) return null;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const BatteryOptimizationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: twainTheme.iconBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.battery_saver_rounded,
              size: 32,
              color: twainTheme.iconColor,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Improve Reliability',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            'For wallpapers to sync reliably in the background, Twain needs to be excluded from battery optimization.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: twainTheme.iconBackgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: twainTheme.iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This won\'t significantly impact your battery life. It just allows Twain to receive wallpapers even when running in the background.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Primary action button
            ElevatedButton(
              onPressed: () => _onEnable(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: twainTheme.iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Enable',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Secondary actions row
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _onRemindLater(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Remind Later',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: theme.dividerColor,
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _onDontAsk(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Don\'t Ask Again',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onEnable(BuildContext context) async {
    // Request battery optimization exemption (shows system dialog)
    final success = await BatteryOptimizationService.requestIgnoreBatteryOptimizations();

    if (context.mounted) {
      Navigator.pop(context, success);
    }
  }

  void _onRemindLater(BuildContext context) {
    // Just dismiss without saving preference - will show again next time
    Navigator.pop(context, false);
  }

  Future<void> _onDontAsk(BuildContext context) async {
    // Save preference to not show again
    await BatteryOptimizationService.setDialogDismissed(true);

    if (context.mounted) {
      Navigator.pop(context, false);
    }
  }
}

/// A simpler banner widget that can be shown in settings or other screens.
class BatteryOptimizationBanner extends StatefulWidget {
  const BatteryOptimizationBanner({super.key});

  @override
  State<BatteryOptimizationBanner> createState() => _BatteryOptimizationBannerState();
}

class _BatteryOptimizationBannerState extends State<BatteryOptimizationBanner> {
  bool _isOptimized = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (!BatteryOptimizationService.isAndroid) {
      setState(() => _isLoading = false);
      return;
    }

    final isIgnoring = await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() {
        _isOptimized = isIgnoring ?? true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show on non-Android or if already optimized
    if (!BatteryOptimizationService.isAndroid || _isLoading || _isOptimized) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.battery_alert_rounded,
              size: 22,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Battery optimization is on',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Background sync may be unreliable',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await BatteryOptimizationService.requestIgnoreBatteryOptimizations();
              // Recheck status after returning from settings
              Future.delayed(const Duration(milliseconds: 500), _checkStatus);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: twainTheme.iconColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Fix',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
