import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/distance_state.dart';
import 'package:twain/models/user_location.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/repositories/location_repository.dart';
import 'package:twain/services/location_service.dart';

const _distanceFeaturePrefKey = 'distance_meter_enabled';
const _defaultFeatureEnabled = true;

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final supabase = Supabase.instance.client;
  return LocationRepository(dbService: dbService, supabase: supabase);
});

final locationPermissionStatusProvider =
    FutureProvider<LocationPermissionStatus>((ref) async {
  return LocationService.checkPermission();
});

final locationFeatureAvailabilityProvider = FutureProvider<bool>((ref) async {
  final status = await ref.watch(locationPermissionStatusProvider.future);
  if (!status.isGranted) return false;

  final enabled = await LocationService.isLocationEnabled();
  return enabled;
});

final distanceFeatureProvider =
    StateNotifierProvider<DistanceFeatureController, AsyncValue<bool>>((ref) {
  return DistanceFeatureController();
});

class DistanceFeatureController extends StateNotifier<AsyncValue<bool>> {
  DistanceFeatureController() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(_distanceFeaturePrefKey) ?? _defaultFeatureEnabled;
      state = AsyncValue.data(enabled);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> setEnabled(bool value) async {
    state = AsyncValue.data(value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_distanceFeaturePrefKey, value);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}

final pairLocationsStreamProvider =
    StreamProvider.autoDispose<List<UserLocation>>((ref) {
  final userAsync = ref.watch(twainUserProvider);
  final featureEnabled = ref.watch(distanceFeatureProvider).maybeWhen(
        data: (value) => value,
        orElse: () => false,
      );

  if (!featureEnabled) {
    return const Stream<List<UserLocation>>.empty();
  }

  return userAsync.when(
    data: (user) {
      final pairId = user?.pairId;
      if (pairId == null) {
        return const Stream<List<UserLocation>>.empty();
      }

      final repository = ref.watch(locationRepositoryProvider);
      return repository.watchPairLocations(pairId);
    },
    loading: () => const Stream<List<UserLocation>>.empty(),
    error: (_, __) => const Stream<List<UserLocation>>.empty(),
  );
});

final distanceStateProvider =
    StateNotifierProvider.autoDispose<DistanceStateNotifier, DistanceState>(
        (ref) {
  return DistanceStateNotifier(ref);
});

class DistanceStateNotifier extends StateNotifier<DistanceState> {
  DistanceStateNotifier(this._ref) : super(const DistanceState.hidden()) {
    _locationSub = _ref.listen<AsyncValue<List<UserLocation>>>(
      pairLocationsStreamProvider,
      (previous, next) => _handleLocations(next),
    );

    _featureSub = _ref.listen<AsyncValue<bool>>(
      distanceFeatureProvider,
      (previous, next) {
        final enabled =
            next.maybeWhen(data: (value) => value, orElse: () => false);
        if (!enabled) {
          state = const DistanceState.hidden();
        }
      },
    );
  }

  final Ref _ref;
  ProviderSubscription<AsyncValue<List<UserLocation>>>? _locationSub;
  ProviderSubscription<AsyncValue<bool>>? _featureSub;
  double? _previousDistance;
  DistanceTrend _lastTrend = DistanceTrend.apart;

  void _handleLocations(AsyncValue<List<UserLocation>> asyncLocations) {
    final featureEnabled = _ref.read(distanceFeatureProvider).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );
    if (!featureEnabled) {
      state = const DistanceState.hidden();
      _previousDistance = null;
      _lastTrend = DistanceTrend.apart;
      return;
    }

    final user = _ref.read(twainUserProvider).value;
    if (user == null || user.pairId == null) {
      state = const DistanceState.hidden();
      _previousDistance = null;
      _lastTrend = DistanceTrend.apart;
      return;
    }

    asyncLocations.when(
      data: (locations) => _updateFromLocations(locations, user.id),
      loading: () {
        if (state.status == DistanceStatus.hidden) {
          state = const DistanceState.acquiring();
          _previousDistance = null;
          _lastTrend = DistanceTrend.apart;
        }
      },
      error: (_, __) {
        state = const DistanceState.hidden();
        _previousDistance = null;
        _lastTrend = DistanceTrend.apart;
      },
    );
  }

  void _updateFromLocations(List<UserLocation> locations, String userId) {
    if (locations.isEmpty) {
      if (state.status == DistanceStatus.hidden) {
        state = const DistanceState.acquiring();
      }
      return;
    }

    final selfLocation = _findSelfLocation(locations, userId);
    final partnerLocation = _findPartnerLocation(locations, userId);

    if (selfLocation == null) {
      state = const DistanceState.hidden();
      _previousDistance = null;
      _lastTrend = DistanceTrend.apart;
      return;
    }

    if (partnerLocation == null) {
      if (state.status == DistanceStatus.ready &&
          state.distanceMeters != null) {
        state = state.copyWith(status: DistanceStatus.waitingForPartner);
      } else {
        state = const DistanceState.waitingForPartner();
      }
      return;
    }

    final distance = DistanceState.haversine(
      startLat: selfLocation.latitude,
      startLng: selfLocation.longitude,
      endLat: partnerLocation.latitude,
      endLng: partnerLocation.longitude,
    );

    final newestTimestamp =
        selfLocation.recordedAt.isAfter(partnerLocation.recordedAt)
            ? selfLocation.recordedAt
            : partnerLocation.recordedAt;

    var trend = _lastTrend;
    if (_previousDistance != null) {
      final diff = _previousDistance! - distance;
      const threshold = 5.0; // meters
      if (diff.abs() >= threshold) {
        trend = diff > 0 ? DistanceTrend.closer : DistanceTrend.apart;
      }
    }

    _previousDistance = distance;
    _lastTrend = trend;

    state = DistanceState.ready(
      distanceMeters: distance,
      lastUpdated: newestTimestamp,
      trend: trend,
    );
  }

  UserLocation? _findSelfLocation(List<UserLocation> locations, String userId) {
    for (final location in locations) {
      if (location.userId == userId) {
        return location;
      }
    }
    return null;
  }

  UserLocation? _findPartnerLocation(
      List<UserLocation> locations, String userId) {
    for (final location in locations) {
      if (location.userId != userId) {
        return location;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _locationSub?.close();
    _featureSub?.close();
    super.dispose();
  }
}
