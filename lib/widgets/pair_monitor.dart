import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/providers/auth_providers.dart';

/// Monitors the user's pair_id and navigates to pairing screen when it becomes null
class PairMonitor extends ConsumerStatefulWidget {
  final Widget child;

  const PairMonitor({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<PairMonitor> createState() => _PairMonitorState();
}

class _PairMonitorState extends ConsumerState<PairMonitor> {
  String? _previousPairId;

  @override
  Widget build(BuildContext context) {
    ref.listen(twainUserProvider, (previous, next) {
      print('PairMonitor: Received update - previous: $previous, next: $next');

      next.whenData((user) {
        if (user != null) {
          final currentPairId = user.pairId;
          print('PairMonitor: Current pair_id: $currentPairId, Previous pair_id: $_previousPairId');

          // If user was paired but now unpaired, navigate to pairing screen
          if (_previousPairId != null && currentPairId == null) {
            print('PairMonitor: User was unpaired! Navigating to pairing screen');

            // Pop all routes to go back to AuthGate which will show pairing screen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                print('PairMonitor: Popping all routes');
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            });
          }

          _previousPairId = currentPairId;
        } else {
          print('PairMonitor: User is null');
        }
      });
    });

    return widget.child;
  }
}
