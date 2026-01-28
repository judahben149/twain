import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Feature that triggered the paywall - used for analytics
enum PaywallFeature {
  wallpaperRotation,
  stickyNoteReplies,
  general,
}

class PaywallScreen {
  /// Show the RevenueCat-designed paywall
  /// Returns true if user successfully subscribed, false otherwise
  static Future<bool> show(
    BuildContext context, {
    PaywallFeature feature = PaywallFeature.general,
  }) async {
    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded('twain_plus');

      // PaywallResult indicates what happened
      switch (result) {
        case PaywallResult.purchased:
        case PaywallResult.restored:
          return true;
        case PaywallResult.notPresented:
          // User already has entitlement
          return true;
        case PaywallResult.cancelled:
        case PaywallResult.error:
          return false;
      }
    } catch (e) {
      debugPrint('PaywallScreen: Error presenting paywall - $e');
      return false;
    }
  }

  /// Show paywall regardless of current entitlement status
  /// Useful for "Manage Subscription" or viewing plans
  static Future<bool> showAlways(BuildContext context) async {
    try {
      final result = await RevenueCatUI.presentPaywall();

      switch (result) {
        case PaywallResult.purchased:
        case PaywallResult.restored:
          return true;
        case PaywallResult.notPresented:
        case PaywallResult.cancelled:
        case PaywallResult.error:
          return false;
      }
    } catch (e) {
      debugPrint('PaywallScreen: Error presenting paywall - $e');
      return false;
    }
  }
}
