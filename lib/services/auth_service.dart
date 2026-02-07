import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart' as google_sign_in;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/supabase_config.dart';
import 'package:twain/repositories/user_repository.dart';
import 'package:twain/services/subscription_service.dart';

class AuthService {
  final _supabase = Supabase.instance.client;
  final UserRepository? _userRepository;

  AuthService({UserRepository? userRepository}) : _userRepository = userRepository;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get userChanges => _supabase.auth.onAuthStateChange.map((data) => data.session?.user);

  // Stream of TwainUser with data from database
  Stream<TwainUser?> twainUserStream() {
    return _supabase.auth.onAuthStateChange.asyncExpand((data) async* {
      final user = data.session?.user;
      if (user == null) {
        print('twainUserStream: No user in auth state');
        yield null;
        return;
      }

      print('twainUserStream: Auth state changed for user ${user.id}');

      // If repository is available, use cache-first strategy
      if (_userRepository != null) {
        print('twainUserStream: Using UserRepository with cache-first strategy');
        yield* _userRepository!.watchCurrentUser(user.id);
      } else {
        // Fallback to direct Supabase stream (original behavior)
        print('twainUserStream: No repository, using direct Supabase stream');

        // First, immediately fetch and yield current user data
        final currentUser = await _getUserFromSupabase(user.id);
        print('twainUserStream: Initial fetch returned: ${currentUser?.displayName ?? "null"}');
        yield currentUser;

        // Then stream real-time changes from the users table for this specific user
        print('twainUserStream: Starting database stream for user ${user.id}');
        yield* _supabase
            .from('users')
            .stream(primaryKey: ['id'])
            .eq('id', user.id)
            .map((rows) {
              print('twainUserStream: Database stream emitted ${rows.length} rows');
              if (rows.isEmpty) return null;
              final data = rows.first;
              final twainUser = TwainUser(
                id: data['id'],
                email: data['email'],
                displayName: data['display_name'],
                nickname: data['nickname'],
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
              print('twainUserStream: Mapped to TwainUser with displayName: ${twainUser.displayName}');
              return twainUser;
            })
            .distinct((prev, next) {
              // Only emit when the user actually changes to avoid duplicate emissions
              final isSame = prev?.id == next?.id &&
                     prev?.displayName == next?.displayName &&
                     prev?.avatarUrl == next?.avatarUrl &&
                     prev?.pairId == next?.pairId &&
                     prev?.updatedAt == next?.updatedAt;
              if (isSame) {
                print('twainUserStream: Filtered duplicate emission');
              }
              return isSame;
            });
      }
    });
  }

  Future<void> updateUserPreferences(Map<String, dynamic> preferences) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      print('updateUserPreferences: No authenticated user');
      return;
    }
    try {
      await _supabase.from('users').update({'preferences': preferences}).eq('id', user.id);
      if (_userRepository != null) {
        final cachedUser = await _userRepository!.getCachedUser(user.id);
        if (cachedUser != null) {
          final updatedUser = cachedUser.copyWith(preferences: preferences);
          await _userRepository!.cacheUser(updatedUser);
        }
      }
    } catch (e) {
      print('updateUserPreferences error: $e');
      rethrow;
    }
  }

  // Sign in with Google (Native)
  Future<TwainUser?> signInWithGoogle() async {
    try {
      // Get the already-initialized GoogleSignIn instance
      final googleSignIn = google_sign_in.GoogleSignIn.instance;

      // Authenticate the user - this shows native Android Credential Manager UI
      final googleUser = await googleSignIn.authenticate();

      // Get the authentication tokens directly without requesting additional scopes
      // This avoids triggering the WebView flow
      final idToken = googleUser.authentication.idToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token from Google');
      }

      // For Supabase, we primarily need the ID token
      // Access token can be obtained from authorization if needed later
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = response.user;
      if (user == null) return null;

      // Create or update user in database
      await _createOrUpdateUser(user);

      // Set user ID in RevenueCat for subscription tracking
      await SubscriptionService.instance.setUserId(user.id);

      return await _getUserFromSupabase(user.id);
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<TwainUser?> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) return null;

      // Ensure user record exists in database
      await _createOrUpdateUser(user);

      // Set user ID in RevenueCat for subscription tracking
      await SubscriptionService.instance.setUserId(user.id);

      return await _getUserFromSupabase(user.id);
    } catch (e) {
      print('Error signing in with email: $e');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<void> signUpWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      // Note: User won't be signed in until they verify their email
      // The user record in database will be created via a trigger or
      // when they first sign in after verification

      if (response.user == null) {
        throw Exception('Failed to create account');
      }

      // Success - user needs to check email for confirmation link
    } catch (e) {
      print('Error signing up: $e');
      rethrow;
    }
  }

  // Sign in with magic link (passwordless)
  Future<void> signInWithMagicLink(String email) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'io.supabase.twain://login-callback/',
      );
    } catch (e) {
      print('Error sending magic link: $e');
      rethrow;
    }
  }

  // Verify email OTP code
  Future<void> verifyEmailOTP(String email, String token) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Failed to verify code');
      }

      // Create or update user in database
      await _createOrUpdateUser(user);

      // Set user ID in RevenueCat for subscription tracking
      await SubscriptionService.instance.setUserId(user.id);
    } catch (e) {
      print('Error verifying OTP: $e');
      rethrow;
    }
  }

  // Resend email OTP code
  Future<void> resendEmailOTP(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } catch (e) {
      print('Error resending OTP: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear cached data before signing out
      if (_userRepository != null) {
        await _userRepository!.clearAllCache();
        print('signOut: Cleared user cache');
      }

      // Clear RevenueCat user ID
      await SubscriptionService.instance.clearUserId();

      await google_sign_in.GoogleSignIn.instance.signOut();
      await _supabase.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Create or update user in database
  Future<void> _createOrUpdateUser(User user) async {
    try {
      final existingUser = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingUser == null) {
        // Create new user
        print('Creating new user in database: ${user.id}');
        await _supabase.from('users').insert({
          'id': user.id,
          'email': user.email!,
          'display_name': user.userMetadata?['display_name'] ??
                         user.userMetadata?['full_name'] ??
                         user.userMetadata?['name'] ??
                         user.email!.split('@')[0],
          'avatar_url': user.userMetadata?['avatar_url'] ??
                       user.userMetadata?['picture'],
          'status': 'online',
          'last_active_at': DateTime.now().toUtc().toIso8601String(),
        });
        print('User created successfully in database');
      } else {
        // Update existing user's updated_at timestamp
        // The trigger in database will handle this automatically
        print('Updating existing user in database: ${user.id}');
        await _supabase.from('users').update({
          'avatar_url': user.userMetadata?['avatar_url'] ??
                       user.userMetadata?['picture'] ??
                       existingUser['avatar_url'],
        }).eq('id', user.id);
      }
    } catch (e) {
      print('Error in _createOrUpdateUser: $e');
      rethrow;
    }
  }

  // Get TwainUser from Supabase database
  Future<TwainUser?> _getUserFromSupabase(String uid) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (data == null) return null;

      final lastActiveString = data['last_active_at'] as String?;

      return TwainUser(
        id: data['id'],
        email: data['email'],
        displayName: data['display_name'],
        nickname: data['nickname'],
        avatarUrl: data['avatar_url'],
        pairId: data['pair_id'],
        fcmToken: data['fcm_token'],
        deviceId: data['device_id'],
        status: data['status'],
        lastActiveAt:
            lastActiveString != null ? DateTime.tryParse(lastActiveString) : null,
        createdAt: DateTime.parse(data['created_at']),
        updatedAt: DateTime.parse(data['updated_at']),
        preferences: data['preferences'],
        metaData: data['metadata'],
      );
    } catch (e) {
      print('Error getting user from Supabase: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? nickname,
    String? avatarUrl,
    String? status,
    String? fcmToken,
    String? deviceId,
    DateTime? lastActiveAt,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? metadata,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (nickname != null) updates['nickname'] = nickname;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (status != null) updates['status'] = status;
    if (fcmToken != null) updates['fcm_token'] = fcmToken;
    if (deviceId != null) updates['device_id'] = deviceId;
    if (lastActiveAt != null) {
      updates['last_active_at'] = lastActiveAt.toUtc().toIso8601String();
    }
    if (preferences != null) updates['preferences'] = preferences;
    if (metadata != null) updates['metadata'] = metadata;

    await _supabase.from('users').update(updates).eq('id', user.id);
  }

  Future<void> setPresenceOnline() => _updatePresence('online');

  Future<void> setPresenceAway() => _updatePresence('away');

  Future<void> _updatePresence(String status) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await _supabase.from('users').update({
        'status': status,
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
    } catch (error) {
      print('Error updating presence: $error');
    }
  }

  // Pair with another user
  Future<void> pairWithUser(String pairId) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    await _supabase.from('users').update({
      'pair_id': pairId,
    }).eq('id', user.id);
  }

  // Unpair from current partner
  Future<void> unpair() async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    print('unpair: Starting disconnect process');

    try {
      // Clear partner cache before unpairing
      // Note: We clear all cache since sticky notes will also be deleted
      if (_userRepository != null) {
        await _userRepository!.clearAllCache();
        print('unpair: Cleared user cache');
      }

      // Call SECURITY DEFINER function to unpair both users and clean up data
      // This bypasses RLS to update both users
      await _supabase.rpc('unpair_users');

      print('unpair: Successfully unpaired users');
    } catch (e) {
      print('unpair: Error during unpair: $e');
      rethrow;
    }
  }

  // Get paired user
  Future<TwainUser?> getPairedUser() async {
    final user = currentUser;
    if (user == null) {
      print('getPairedUser: No current user');
      return null;
    }

    print('getPairedUser: Getting current user data for ${user.id}');
    final currentUserData = await _getUserFromSupabase(user.id);
    print('getPairedUser: Current user pair_id = ${currentUserData?.pairId}');

    if (currentUserData?.pairId == null) {
      print('getPairedUser: No pair_id found');
      return null;
    }

    // Find the other user with the same pair_id
    print('getPairedUser: Searching for partner with pair_id = ${currentUserData!.pairId} and id != ${user.id}');
    final partnerData = await _supabase
        .from('users')
        .select()
        .eq('pair_id', currentUserData.pairId!)
        .neq('id', user.id)
        .maybeSingle();

    print('getPairedUser: Query returned: ${partnerData?.toString()}');

    if (partnerData == null) {
      print('getPairedUser: No partner found');
      return null;
    }

    final partner = TwainUser(
      id: partnerData['id'],
      email: partnerData['email'],
      displayName: partnerData['display_name'],
      nickname: partnerData['nickname'],
      avatarUrl: partnerData['avatar_url'],
      pairId: partnerData['pair_id'],
      fcmToken: partnerData['fcm_token'],
      deviceId: partnerData['device_id'],
      status: partnerData['status'],
      lastActiveAt: partnerData['last_active_at'] != null
          ? DateTime.tryParse(partnerData['last_active_at'])
          : null,
      createdAt: DateTime.parse(partnerData['created_at']),
      updatedAt: DateTime.parse(partnerData['updated_at']),
      preferences: partnerData['preferences'],
      metaData: partnerData['metadata'],
    );

    print('getPairedUser: Returning partner: ${partner.displayName}');
    return partner;
  }

  // Stream of paired user with real-time updates
  Stream<TwainUser?> pairedUserStream() {
    return twainUserStream().asyncExpand((currentUser) async* {
      if (currentUser?.pairId == null) {
        print('pairedUserStream: No pair_id, yielding null');
        yield null;
        return;
      }

      print('pairedUserStream: Current user has pair_id ${currentUser!.pairId}');

      // If repository is available, use cache-first strategy
      if (_userRepository != null) {
        print('pairedUserStream: Using UserRepository with cache-first strategy');
        yield* _userRepository!.watchPairedUser(currentUser.id, currentUser.pairId);
      } else {
        // Fallback to direct Supabase stream (original behavior)
        print('pairedUserStream: No repository, using direct Supabase stream');

        // Stream real-time changes from the users table for the partner
        yield* _supabase
            .from('users')
            .stream(primaryKey: ['id'])
            .eq('pair_id', currentUser.pairId!)
            .map((rows) {
              print('pairedUserStream: Database stream emitted ${rows.length} rows');

              // Filter out the current user from the results
              final partnerRows = rows.where((row) => row['id'] != currentUser.id).toList();

              if (partnerRows.isEmpty) {
                print('pairedUserStream: No partner found after filtering');
                return null;
              }

              final data = partnerRows.first;
              final partner = TwainUser(
                id: data['id'],
                email: data['email'],
                displayName: data['display_name'],
                nickname: data['nickname'],
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
              print('pairedUserStream: Mapped to partner with displayName: ${partner.displayName}, avatarUrl: ${partner.avatarUrl}');
              return partner;
            })
            .distinct((prev, next) {
              // Only emit when partner data actually changes
              final isSame = prev?.id == next?.id &&
                  prev?.displayName == next?.displayName &&
                  prev?.avatarUrl == next?.avatarUrl &&
                  prev?.pairId == next?.pairId &&
                  prev?.updatedAt == next?.updatedAt;
              if (isSame) {
                print('pairedUserStream: Filtered duplicate emission');
              }
              return isSame;
            });
      }
    });
  }

  // Get existing invite code for current user (if any)
  Future<String?> getExistingInviteCode() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final userData = await _supabase
          .from('users')
          .select('invite_code')
          .eq('id', user.id)
          .maybeSingle();

      return userData?['invite_code'] as String?;
    } catch (e) {
      print('Error getting existing invite code: $e');
      return null;
    }
  }

  // Generate a unique invite code for the current user
  Future<String> generateInviteCode() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      print('Generating invite code for user: ${user.id}');

      // Generate a random 6-character code
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed confusing chars
      final random = DateTime.now().microsecondsSinceEpoch;
      String code = '';

      // Generate code based on timestamp and randomness
      for (int i = 0; i < 6; i++) {
        code += chars[(random + i * 7) % chars.length];
      }

      print('Generated code: $code, checking for collisions...');

      // Check if code already exists, if so generate a new one
      final existing = await _supabase
          .from('users')
          .select()
          .eq('invite_code', code)
          .maybeSingle();

      if (existing != null) {
        print('Code collision detected, generating new code...');
        // Recursively generate a new code if collision
        return generateInviteCode();
      }

      print('No collision, storing code in database...');

      // Store the code in the user's record
      await _supabase.from('users').update({
        'invite_code': code,
      }).eq('id', user.id);

      print('Successfully generated and stored invite code: $code for user ${user.id}');
      return code;
    } catch (e) {
      print('Error generating invite code: $e');
      rethrow;
    }
  }

  // Pair with another user using their invite code
  Future<void> pairWithCode(String code) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      final normalizedCode = code.trim().toUpperCase();
      print('Attempting to pair with code: $normalizedCode');

      // Call the database function to pair both users
      // This uses SECURITY DEFINER to bypass RLS and update both users
      await _supabase.rpc('pair_users_by_code', params: {
        'invite_code_param': normalizedCode,
      });

      print('Successfully paired with user using code: $normalizedCode');
    } catch (e) {
      print('Error pairing with code: $e');

      // Parse PostgreSQL errors into user-friendly messages
      final errorMessage = e.toString();
      if (errorMessage.contains('Invalid invite code')) {
        throw Exception('Invalid invite code');
      } else if (errorMessage.contains('Cannot pair with yourself')) {
        throw Exception('You cannot pair with yourself');
      } else if (errorMessage.contains('already paired')) {
        throw Exception('This user is already paired with someone else');
      } else {
        rethrow;
      }
    }
  }
}
