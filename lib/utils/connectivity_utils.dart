import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/providers/connectivity_provider.dart';

/// Quick connectivity gate for user-initiated actions.
///
/// Returns `true` if connected. When offline, shows a SnackBar and returns
/// `false` so the caller can early-return.
bool checkConnectivity(BuildContext context, WidgetRef ref) {
  final isConnected = ref.read(isConnectedProvider);
  if (isConnected) return true;

  final twainTheme = context.twainTheme;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: const Text(
        'No internet connection. Please check your network and try again.',
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: twainTheme.destructiveColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  return false;
}
