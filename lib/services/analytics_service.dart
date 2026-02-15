import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(FirebaseAnalytics.instance);
});

class AnalyticsService {
  AnalyticsService(FirebaseAnalytics analytics) : _analytics = analytics;

  final FirebaseAnalytics _analytics;

  late final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  FirebaseAnalytics get instance => _analytics;

  Future<void> logAppOpen() {
    return _analytics.logAppOpen();
  }

  Future<void> setUserId(String? userId) {
    return _analytics.setUserId(id: userId);
  }

  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }
}
