import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:twain/models/subscription_status.dart';

/// RevenueCat configuration
class RevenueCatConfig {
  // API Keys - Replace with production keys before release
  static const String androidApiKey = 'test_jthDZxTflUCGYNCfjSOPyZYwOTk';
  static const String iosApiKey = 'test_jthDZxTflUCGYNCfjSOPyZYwOTk'; // TODO: Add iOS key

  // Entitlement ID - This is what you set up in RevenueCat dashboard
  static const String premiumEntitlement = 'twain_plus';

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

  /// Refresh subscription status from RevenueCat
  Future<SubscriptionStatus> refreshStatus() async {
    if (!_isInitialized) return SubscriptionStatus.free;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final status = _parseCustomerInfo(customerInfo);
      _updateStatus(status);
      return status;
    } catch (e) {
      debugPrint('SubscriptionService: Failed to refresh status - $e');
      return _currentStatus;
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
    final status = _parseCustomerInfo(customerInfo);
    _updateStatus(status);
  }

  void _updateStatus(SubscriptionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
    debugPrint('SubscriptionService: Status updated - $status');
  }

  SubscriptionStatus _parseCustomerInfo(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.active[RevenueCatConfig.premiumEntitlement];

    if (entitlement == null || !entitlement.isActive) {
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
