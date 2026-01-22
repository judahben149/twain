import 'package:flutter/material.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/services/location_service.dart';

class LocationPermissionDialog extends StatefulWidget {
  const LocationPermissionDialog({super.key});

  static Future<bool?> show(BuildContext context) async {
    if (!LocationService.isSupported) return null;

    final status = await LocationService.checkPermission();
    if (status.isGranted || status.isPermanentlyDenied) return null;

    final shouldShow = await LocationService.shouldShowPermissionDialog();
    if (!shouldShow) return null;

    await LocationService.markPromptShown();

    if (!context.mounted) return null;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LocationPermissionDialog(),
    );
  }

  @override
  State<LocationPermissionDialog> createState() => _LocationPermissionDialogState();
}

class _LocationPermissionDialogState extends State<LocationPermissionDialog> {
  bool _isProcessing = false;
  String? _error;

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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: twainTheme.iconBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_outlined,
              size: 32,
              color: twainTheme.iconColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Distance Meter',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Share your location to see how far you and your partner are right now.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
                  Icons.lock_outline,
                  size: 20,
                  color: twainTheme.iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your location is only shared with your partner and is cleared regularly.',
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isProcessing ? null : _onEnable,
              style: ElevatedButton.styleFrom(
                backgroundColor: twainTheme.iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Enable Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isProcessing ? null : _onMaybeLater,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Maybe Later',
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
                    onPressed: _isProcessing ? null : _onDontAskAgain,
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

  Future<void> _onEnable() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final status = await LocationService.requestPermission();

    if (!mounted) return;

    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        await LocationService.setDontAskAgain(true);
      }
      setState(() {
        _isProcessing = false;
        _error = 'Please enable location in system settings to use the distance meter.';
      });
      return;
    }

    final enabled = await LocationService.isLocationEnabled();
    if (!mounted) return;

    if (!enabled) {
      setState(() {
        _isProcessing = false;
        _error = 'Turn on location services to calculate your distance.';
      });
      return;
    }

    Navigator.pop(context, true);
  }

  void _onMaybeLater() {
    Navigator.pop(context, false);
  }

  Future<void> _onDontAskAgain() async {
    await LocationService.setDontAskAgain(true);
    if (!mounted) return;
    Navigator.pop(context, false);
  }
}
