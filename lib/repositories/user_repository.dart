import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/services/database_service.dart';

class UserRepository {
  final DatabaseService _dbService;
  final SupabaseClient _supabase;

  // Stream controllers for reactive caching
  final _currentUserController = StreamController<TwainUser?>.broadcast();
  final _pairedUserController = StreamController<TwainUser?>.broadcast();

  // Active subscriptions
  StreamSubscription? _supabaseUserSubscription;
  StreamSubscription? _supabasePairedUserSubscription;

  UserRepository({
    required DatabaseService dbService,
    required SupabaseClient supabase,
  })  : _dbService = dbService,
        _supabase = supabase;

  // Get current user's Supabase auth user
  User? get currentAuthUser => _supabase.auth.currentUser;

  // Stream current user with cache-first strategy
  Stream<TwainUser?> watchCurrentUser(String userId) async* {
    print('UserRepository: Starting watchCurrentUser for $userId');

    // Step 1: Immediately yield cached data
    final cachedUser = await _dbService.getUser(userId);
    print('UserRepository: Yielding cached user: ${cachedUser?.displayName ?? "null"}');
    yield cachedUser;

    // Step 2: Subscribe to Supabase real-time stream with automatic reconnection
    var shouldReconnect = true;
    while (shouldReconnect) {
      try {
        await for (final rows in _supabase
            .from('users')
            .stream(primaryKey: ['id'])
            .eq('id', userId)) {
          if (rows.isEmpty) {
            print('UserRepository: No user data from Supabase stream');
            yield null;
            continue;
          }

          final data = rows.first;
          final user = TwainUser(
            id: data['id'],
            email: data['email'],
            displayName: data['display_name'],
            avatarUrl: data['avatar_url'],
            pairId: data['pair_id'],
            fcmToken: data['fcm_token'],
            deviceId: data['device_id'],
            status: data['status'],
            createdAt: DateTime.parse(data['created_at']),
            updatedAt: DateTime.parse(data['updated_at']),
            preferences: data['preferences'],
            metaData: data['metadata'],
          );

          // Cache the updated user
          await _dbService.saveUser(user);
          print('UserRepository: Updated cache for user ${user.displayName}');

          yield user;
        }
      } catch (error) {
        print('UserRepository: Stream error (likely offline): $error');
        print('UserRepository: Will retry connection in 5 seconds...');

        // Wait before retrying
        await Future.delayed(const Duration(seconds: 5));
        print('UserRepository: Attempting to reconnect...');
      }
    }
  }

  // Stream paired user with cache-first strategy
  Stream<TwainUser?> watchPairedUser(String userId, String? pairId) async* {
    print('UserRepository: Starting watchPairedUser for pairId: $pairId');

    if (pairId == null) {
      print('UserRepository: No pairId, yielding null');
      yield null;
      return;
    }

    // Step 1: Immediately yield cached partner data
    final cachedPartner = await _dbService.getUserByPairId(pairId, userId);
    print('UserRepository: Yielding cached partner: ${cachedPartner?.displayName ?? "null"}');
    yield cachedPartner;

    // Step 2: Subscribe to Supabase real-time stream for partner with automatic reconnection
    var shouldReconnect = true;
    while (shouldReconnect) {
      try {
        await for (final rows in _supabase
            .from('users')
            .stream(primaryKey: ['id'])
            .eq('pair_id', pairId)) {
          print('UserRepository: Partner stream emitted ${rows.length} rows');

          // Filter out the current user
          final partnerRows = rows.where((row) => row['id'] != userId).toList();

          if (partnerRows.isEmpty) {
            print('UserRepository: No partner found after filtering');
            yield null;
            continue;
          }

          final data = partnerRows.first;
          final partner = TwainUser(
            id: data['id'],
            email: data['email'],
            displayName: data['display_name'],
            avatarUrl: data['avatar_url'],
            pairId: data['pair_id'],
            fcmToken: data['fcm_token'],
            deviceId: data['device_id'],
            status: data['status'],
            createdAt: DateTime.parse(data['created_at']),
            updatedAt: DateTime.parse(data['updated_at']),
            preferences: data['preferences'],
            metaData: data['metadata'],
          );

          print('UserRepository: Mapped partner: ${partner.displayName}');

          // Cache the updated partner
          await _dbService.saveUser(partner);
          print('UserRepository: Updated cache for partner ${partner.displayName}');

          yield partner;
        }
      } catch (error) {
        print('UserRepository: Partner stream error (likely offline): $error');
        print('UserRepository: Will retry partner connection in 5 seconds...');

        // Wait before retrying
        await Future.delayed(const Duration(seconds: 5));
        print('UserRepository: Attempting to reconnect partner stream...');
      }
    }
  }

  // Get cached user (one-time fetch, no streaming)
  Future<TwainUser?> getCachedUser(String userId) async {
    return await _dbService.getUser(userId);
  }

  // Get cached partner (one-time fetch, no streaming)
  Future<TwainUser?> getCachedPartner(String pairId, String userId) async {
    return await _dbService.getUserByPairId(pairId, userId);
  }

  // Cache a user manually
  Future<void> cacheUser(TwainUser user) async {
    await _dbService.saveUser(user);
  }

  // Clear all cached user data (on logout)
  Future<void> clearAllCache() async {
    print('UserRepository: Clearing all user cache');
    await _dbService.clearAllUsers();
  }

  // Clear cached partner data (on unpair)
  Future<void> clearPartnerCache(String partnerId) async {
    print('UserRepository: Clearing partner cache for $partnerId');
    await _dbService.deleteUser(partnerId);
  }

  // Dispose streams
  Future<void> dispose() async {
    await _supabaseUserSubscription?.cancel();
    await _supabasePairedUserSubscription?.cancel();
    await _currentUserController.close();
    await _pairedUserController.close();
  }
}
