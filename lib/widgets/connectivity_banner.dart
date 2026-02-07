import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/providers/connectivity_provider.dart';

/// A banner that overlays "No internet connection" just below the AppBar when
/// offline, like YouTube's connectivity banner. Uses [MaterialApp.builder] so
/// it appears on every route without per-screen changes.
class ConnectivityBanner extends ConsumerWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider);
    // Position the banner just below the status bar + standard AppBar.
    final topOffset = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Stack(
      children: [
        child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          // Slide off-screen when connected, below AppBar when disconnected.
          top: isConnected ? -50 : topOffset,
          left: 0,
          right: 0,
          child: Material(
            color: const Color(0xFFD32F2F),
            elevation: 6,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'No internet connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
