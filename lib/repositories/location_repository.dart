import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/user_location.dart';
import 'package:twain/services/database_service.dart';
import 'package:twain/services/location_service.dart';

class LocationRepository {
  final DatabaseService _dbService;
  final SupabaseClient _supabase;

  LocationRepository({
    required DatabaseService dbService,
    required SupabaseClient supabase,
  })  : _dbService = dbService,
        _supabase = supabase;

  Future<void> updateLocation({
    required String userId,
    required String pairId,
    required LocationReading reading,
  }) async {
    try {
      await _supabase.from('user_locations').insert({
        'user_id': userId,
        'pair_id': pairId,
        'latitude': reading.latitude,
        'longitude': reading.longitude,
        'accuracy': reading.accuracy,
        'recorded_at': reading.timestamp.toUtc().toIso8601String(),
      });
    } catch (error) {
      print('LocationRepository.updateLocation error: $error');
      rethrow;
    }
  }

  Stream<List<UserLocation>> watchPairLocations(String pairId) {
    return Stream.multi((controller) async {
      final cached = await _dbService.getUserLocationsByPairId(pairId);
      if (!controller.isClosed) {
        controller.add(cached);
      }

      var fetchInProgress = false;
      var pendingFetch = false;

      Future<void> fetchAndEmit() async {
        if (controller.isClosed) return;
        if (fetchInProgress) {
          pendingFetch = true;
          return;
        }

        fetchInProgress = true;
        do {
          pendingFetch = false;
          try {
            final locations = await _fetchLatestLocations(pairId);
            await _dbService.saveUserLocations(locations);
            if (!controller.isClosed) {
              controller.add(locations);
            }
          } catch (error, stack) {
            if (!controller.isClosed) {
              controller.addError(error, stack);
            }
          }
        } while (pendingFetch && !controller.isClosed);

        fetchInProgress = false;
      }

      final channel = _supabase
          .channel('user_locations_stream_$pairId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'user_locations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'pair_id',
              value: pairId,
            ),
            callback: (_) => unawaited(fetchAndEmit()),
          )
          .subscribe();

      await fetchAndEmit();

      controller.onCancel = () async {
        try {
          await _supabase.removeChannel(channel);
        } catch (_) {}
      };
    });
  }

  Future<List<UserLocation>> _fetchLatestLocations(String pairId) async {
    final response = await _supabase
        .from('user_locations')
        .select()
        .eq('pair_id', pairId)
        .order('recorded_at', ascending: false)
        .limit(50);

    final byUser = <String, UserLocation>{};

    for (final row in response) {
      final map = Map<String, dynamic>.from(row as Map);
      final userId = map['user_id'] as String?;
      if (userId == null) continue;
      if (byUser.containsKey(userId)) continue;
      try {
        byUser[userId] = UserLocation.fromJson(map);
      } catch (error) {
        print('LocationRepository._fetchLatestLocations parse error: $error');
      }
    }

    return byUser.values.toList();
  }
}
