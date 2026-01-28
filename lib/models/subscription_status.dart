/// Represents the user's subscription status
class SubscriptionStatus {
  final bool isSubscribed;
  final String? activeProductId;
  final DateTime? expirationDate;
  final bool willRenew;

  const SubscriptionStatus({
    required this.isSubscribed,
    this.activeProductId,
    this.expirationDate,
    this.willRenew = false,
  });

  /// Default free status
  static const free = SubscriptionStatus(isSubscribed: false);

  /// Check if user has Twain Plus
  bool get isTwainPlus => isSubscribed;

  /// Check if subscription is expiring soon (within 7 days)
  bool get isExpiringSoon {
    if (expirationDate == null || !isSubscribed) return false;
    final daysUntilExpiry = expirationDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7 && daysUntilExpiry > 0;
  }

  SubscriptionStatus copyWith({
    bool? isSubscribed,
    String? activeProductId,
    DateTime? expirationDate,
    bool? willRenew,
  }) {
    return SubscriptionStatus(
      isSubscribed: isSubscribed ?? this.isSubscribed,
      activeProductId: activeProductId ?? this.activeProductId,
      expirationDate: expirationDate ?? this.expirationDate,
      willRenew: willRenew ?? this.willRenew,
    );
  }

  @override
  String toString() {
    return 'SubscriptionStatus(isSubscribed: $isSubscribed, activeProductId: $activeProductId, expirationDate: $expirationDate, willRenew: $willRenew)';
  }
}

/// Available subscription offerings
class SubscriptionOffering {
  final String identifier;
  final String title;
  final String description;
  final List<SubscriptionPackage> packages;

  const SubscriptionOffering({
    required this.identifier,
    required this.title,
    required this.description,
    required this.packages,
  });
}

/// Individual subscription package (monthly, annual, etc.)
class SubscriptionPackage {
  final String identifier;
  final String productId;
  final String title;
  final String priceString;
  final double price;
  final String currencyCode;
  final String? periodUnit; // 'month', 'year'
  final int? periodValue;
  final dynamic rcPackage; // The actual RevenueCat Package object

  const SubscriptionPackage({
    required this.identifier,
    required this.productId,
    required this.title,
    required this.priceString,
    required this.price,
    required this.currencyCode,
    this.periodUnit,
    this.periodValue,
    this.rcPackage,
  });

  /// Returns savings percentage compared to monthly if this is annual
  String? get savingsText {
    if (periodUnit != 'year') return null;
    // This would be calculated based on monthly price
    return null; // Will be calculated when we have real prices
  }

  bool get isMonthly => periodUnit == 'month';
  bool get isAnnual => periodUnit == 'year';
}
