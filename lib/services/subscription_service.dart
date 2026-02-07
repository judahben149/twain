import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/subscription_status.dart';

/// RevenueCat configuration
class RevenueCatConfig {
  // API Keys
  static const String androidApiKey = 'goog_KRbvdZPJdZKoBDdcFUMnpomIpij';
  static const String iosApiKey = ''; // TODO: Add iOS key when available

  // Entitlement ID (must match exactly what's configured in RevenueCat dashboard)
  static const String premiumEntitlement = 'Twain Plus';

  // Product IDs from Play Console
  static const String monthlyProductId = 'twain_plus_v1:monthly-autorenewing';
  static const String annualProductId = 'twain_plus_v1:annual-autorenewing';
}

/// Service for managing subscriptions via RevenueCat
class SubscriptionService {
  static SubscriptionService? _instance;
  static SubscriptionService get instance => _instance ??= SubscriptionService._();

  SubscriptionService._();

  final _statusController = StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get statusStream => _statusController.stream;

  SubscriptionStatus _currentStatus = SubscriptionStatus.free;
  SubscriptionStatus get currentStatus => _currentStatus;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize RevenueCat SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final apiKey = Platform.isAndroid
          ? RevenueCatConfig.androidApiKey
          : RevenueCatConfig.iosApiKey;

      final configuration = PurchasesConfiguration(apiKey);

      await Purchases.configure(configuration);

      // Enable debug logs in debug mode
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      // Listen to customer info updates
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

      // Fetch initial status
      await refreshStatus();

      // Pre-fetch offerings to speed up paywall loading
      try {
        await Purchases.getOfferings();
        debugPrint('SubscriptionService: Offerings pre-fetched');
      } catch (e) {
        debugPrint('SubscriptionService: Failed to pre-fetch offerings - $e');
      }

      _isInitialized = true;
      debugPrint('SubscriptionService: Initialized successfully');
    } catch (e) {
      debugPrint('SubscriptionService: Failed to initialize - $e');
      // Don't throw - app should work without subscriptions
    }
  }

  /// Set user ID for RevenueCat (call after login)
  Future<void> setUserId(String userId) async {
    if (!_isInitialized) return;

    try {
      await Purchases.logIn(userId);
      await refreshStatus();
      debugPrint('SubscriptionService: Set user ID - $userId');
    } catch (e) {
      debugPrint('SubscriptionService: Failed to set user ID - $e');
    }
  }

  /// Clear user ID (call on logout)
  Future<void> clearUserId() async {
    if (!_isInitialized) return;

    try {
      await Purchases.logOut();
      _updateStatus(SubscriptionStatus.free);
      debugPrint('SubscriptionService: Cleared user ID');
    } catch (e) {
      debugPrint('SubscriptionService: Failed to clear user ID - $e');
    }
  }

  /// Refresh subscription status from RevenueCat and check partner subscription
  Future<SubscriptionStatus> refreshStatus() async {
    if (!_isInitialized) return SubscriptionStatus.free;

    try {
      // First check local RevenueCat status
      final customerInfo = await Purchases.getCustomerInfo();
      final localStatus = _parseCustomerInfo(customerInfo);

      if (localStatus.isSubscribed) {
        // User has their own subscription - sync to Supabase for partner to see
        await syncSubscriptionToSupabase(localStatus);
        _updateStatus(localStatus);
        return localStatus;
      }

      // User doesn't have their own subscription - check if partner has Plus
      final partnerStatus = await checkPartnerSubscription();
      if (partnerStatus != null && partnerStatus.isSubscribed) {
        // Partner has Plus, share it with user
        final sharedStatus = partnerStatus.copyWith(isSharedSubscription: true);
        _updateStatus(sharedStatus);
        return sharedStatus;
      }

      // No subscription from either user or partner
      _updateStatus(localStatus);
      return localStatus;
    } catch (e) {
      debugPrint('SubscriptionService: Failed to refresh status - $e');
      return _currentStatus;
    }
  }

  /// Sync current user's subscription status to Supabase
  Future<void> syncSubscriptionToSupabase(SubscriptionStatus status) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        debugPrint('SubscriptionService: No user logged in, skipping sync');
        return;
      }

      await supabase.from('users').update({
        'subscription_status': status.isSubscribed ? 'active' : 'free',
        'subscription_product_id': status.activeProductId,
        'subscription_expires_at': status.expirationDate?.toIso8601String(),
        'subscription_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      debugPrint('SubscriptionService: Synced subscription to Supabase');
    } catch (e) {
      debugPrint('SubscriptionService: Failed to sync subscription to Supabase - $e');
      // Don't throw - this is a non-critical operation
    }
  }

  /// Check if partner has an active subscription
  Future<SubscriptionStatus?> checkPartnerSubscription() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        debugPrint('SubscriptionService: No user logged in');
        return null;
      }

      // Call RPC function to get pair subscription status
      final result = await supabase.rpc(
        'get_pair_subscription_status',
        params: {'user_id': userId},
      );

      if (result == null || (result is List && result.isEmpty)) {
        debugPrint('SubscriptionService: No pair subscription data');
        return null;
      }

      // Handle the result - it could be a list or a single object
      final data = result is List ? result.first : result;

      final hasPlus = data['has_plus'] as bool? ?? false;
      final subscriberId = data['subscriber_id'] as String?;
      final expiresAtStr = data['expires_at'] as String?;

      debugPrint('SubscriptionService: Partner subscription check - hasPlus=$hasPlus, subscriberId=$subscriberId');

      if (!hasPlus) {
        return null;
      }

      // Only return partner subscription if it's not the current user
      if (subscriberId == userId) {
        // This is the user's own subscription
        return null;
      }

      DateTime? expiresAt;
      if (expiresAtStr != null) {
        expiresAt = DateTime.tryParse(expiresAtStr);
      }

      return SubscriptionStatus(
        isSubscribed: true,
        expirationDate: expiresAt,
        isSharedSubscription: true,
      );
    } catch (e) {
      debugPrint('SubscriptionService: Failed to check partner subscription - $e');
      return null;
    }
  }

  /// Get available offerings
  Future<List<SubscriptionOffering>> getOfferings() async {
    if (!_isInitialized) return [];

    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;

      if (current == null) {
        debugPrint('SubscriptionService: No current offering found');
        return [];
      }

      final packages = current.availablePackages.map((package) {
        final product = package.storeProduct;
        String? periodUnit;
        int? periodValue;

        // Parse subscription period from package identifier or product ID
        // RevenueCat standard identifiers: $rc_monthly, $rc_annual, etc.
        final pkgId = package.identifier.toLowerCase();
        if (pkgId.contains('annual') || pkgId.contains('yearly')) {
          periodUnit = 'year';
          periodValue = 1;
        } else if (pkgId.contains('monthly')) {
          periodUnit = 'month';
          periodValue = 1;
        }

        return SubscriptionPackage(
          identifier: package.identifier,
          productId: product.identifier,
          title: product.title,
          priceString: product.priceString,
          price: product.price,
          currencyCode: product.currencyCode,
          periodUnit: periodUnit,
          periodValue: periodValue,
          rcPackage: package,
        );
      }).toList();

      return [
        SubscriptionOffering(
          identifier: current.identifier,
          title: 'Twain Plus',
          description: 'Unlock all premium features',
          packages: packages,
        ),
      ];
    } catch (e) {
      debugPrint('SubscriptionService: Failed to get offerings - $e');
      return [];
    }
  }

  /// Purchase a subscription package
  Future<PurchaseResult> purchase(SubscriptionPackage package) async {
    if (!_isInitialized) {
      return PurchaseResult(
        success: false,
        error: 'Subscription service not initialized',
      );
    }

    if (package.rcPackage == null) {
      return PurchaseResult(
        success: false,
        error: 'Invalid package',
      );
    }

    try {
      final customerInfo = await Purchases.purchasePackage(
        package.rcPackage as Package,
      );

      final status = _parseCustomerInfo(customerInfo);
      _updateStatus(status);

      return PurchaseResult(
        success: status.isSubscribed,
        status: status,
      );
    } on PurchasesErrorCode catch (e) {
      debugPrint('SubscriptionService: Purchase error - $e');
      return PurchaseResult(
        success: false,
        error: _getPurchaseErrorMessage(e),
        isCancelled: e == PurchasesErrorCode.purchaseCancelledError,
      );
    } catch (e) {
      debugPrint('SubscriptionService: Purchase failed - $e');
      return PurchaseResult(
        success: false,
        error: 'Purchase failed. Please try again.',
      );
    }
  }

  /// Restore purchases
  Future<PurchaseResult> restorePurchases() async {
    if (!_isInitialized) {
      return PurchaseResult(
        success: false,
        error: 'Subscription service not initialized',
      );
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      final status = _parseCustomerInfo(customerInfo);
      _updateStatus(status);

      if (status.isSubscribed) {
        return PurchaseResult(
          success: true,
          status: status,
        );
      } else {
        return PurchaseResult(
          success: false,
          error: 'No active subscription found',
        );
      }
    } catch (e) {
      debugPrint('SubscriptionService: Restore failed - $e');
      return PurchaseResult(
        success: false,
        error: 'Failed to restore purchases. Please try again.',
      );
    }
  }

  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    debugPrint('SubscriptionService: CustomerInfo update received');
    debugPrint('SubscriptionService: Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
    final status = _parseCustomerInfo(customerInfo);
    debugPrint('SubscriptionService: Parsed status - isSubscribed=${status.isSubscribed}');
    _updateStatus(status);
  }

  void _updateStatus(SubscriptionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
    debugPrint('SubscriptionService: Status updated - $status');
  }

  SubscriptionStatus _parseCustomerInfo(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.active[RevenueCatConfig.premiumEntitlement];
    debugPrint('SubscriptionService._parseCustomerInfo: Looking for entitlement "${RevenueCatConfig.premiumEntitlement}"');
    debugPrint('SubscriptionService._parseCustomerInfo: Entitlement found = ${entitlement != null}, isActive = ${entitlement?.isActive}');

    if (entitlement == null || !entitlement.isActive) {
      debugPrint('SubscriptionService._parseCustomerInfo: Returning FREE status');
      return SubscriptionStatus.free;
    }

    DateTime? expirationDate;
    if (entitlement.expirationDate != null) {
      expirationDate = DateTime.tryParse(entitlement.expirationDate!);
    }

    return SubscriptionStatus(
      isSubscribed: true,
      activeProductId: entitlement.productIdentifier,
      expirationDate: expirationDate,
      willRenew: entitlement.willRenew,
    );
  }

  String _getPurchaseErrorMessage(PurchasesErrorCode error) {
    switch (error) {
      case PurchasesErrorCode.purchaseCancelledError:
        return 'Purchase was cancelled';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device';
      case PurchasesErrorCode.purchaseInvalidError:
        return 'The purchase was invalid';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'This product is not available for purchase';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'You already own this subscription';
      case PurchasesErrorCode.networkError:
        return 'Network error. Please check your connection.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Payment is pending. Please wait.';
      default:
        return 'Purchase failed. Please try again.';
    }
  }

  void dispose() {
    _statusController.close();
  }
}

/// Result of a purchase attempt
class PurchaseResult {
  final bool success;
  final SubscriptionStatus? status;
  final String? error;
  final bool isCancelled;

  const PurchaseResult({
    required this.success,
    this.status,
    this.error,
    this.isCancelled = false,
  });
}
