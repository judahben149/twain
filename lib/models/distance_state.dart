import 'dart:math' as math;

enum DistanceStatus {
  hidden,
  acquiring,
  waitingForPartner,
  ready,
}

enum DistanceTrend {
  closer,
  apart,
}

class DistanceState {
  final DistanceStatus status;
  final DistanceTrend trend;
  final double? distanceMeters;
  final DateTime? lastUpdated;

  const DistanceState._({
    required this.status,
    required this.trend,
    required this.distanceMeters,
    required this.lastUpdated,
  });

  const DistanceState.hidden()
      : status = DistanceStatus.hidden,
        trend = DistanceTrend.apart,
        distanceMeters = null,
        lastUpdated = null;

  const DistanceState.acquiring()
      : status = DistanceStatus.acquiring,
        trend = DistanceTrend.apart,
        distanceMeters = null,
        lastUpdated = null;

  const DistanceState.waitingForPartner()
      : status = DistanceStatus.waitingForPartner,
        trend = DistanceTrend.apart,
        distanceMeters = null,
        lastUpdated = null;

  DistanceState.ready({
    required double distanceMeters,
    required DateTime? lastUpdated,
    required DistanceTrend trend,
  }) : this._(
          status: DistanceStatus.ready,
          trend: trend,
          distanceMeters: distanceMeters,
          lastUpdated: lastUpdated,
        );

  DistanceState copyWith({
    DistanceStatus? status,
    DistanceTrend? trend,
    double? distanceMeters,
    DateTime? lastUpdated,
  }) {
    return DistanceState._(
      status: status ?? this.status,
      trend: trend ?? this.trend,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  String formatDistance({bool includeUnits = true}) {
    final meters = distanceMeters;
    if (meters == null) return includeUnits ? '--' : '';
    if (meters < 1000) {
      final rounded = meters.round();
      return includeUnits ? '$rounded m' : '$rounded';
    }

    final km = meters / 1000;
    final rounded = (km * 10).roundToDouble() / 10;
    if ((rounded - rounded.floor()).abs() < 1e-6) {
      return includeUnits ? '${rounded.floor()} km' : '${rounded.floor()}';
    }

    return includeUnits
        ? '${rounded.toStringAsFixed(1)} km'
        : rounded.toStringAsFixed(1);
  }

  static double haversine({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(startLat)) *
            math.cos(_toRadians(endLat)) *
            math.pow(math.sin(dLng / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180);
}
