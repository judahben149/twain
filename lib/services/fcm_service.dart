import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/wallpaper.dart';
import 'package:twain/services/wallpaper_manager_service.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('FCM Background: Handling message: ${message.messageId}');

  if (message.data['type'] == 'wallpaper_sync') {
    final wallpaperId = message.data['wallpaper_id'];
    print('FCM Background: Wallpaper sync requested for ID: $wallpaperId');

    // Initialize Supabase if not already initialized
    try {
      // Note: In production, you would need to initialize Supabase here
      // with the proper URL and anon key from environment variables
      // For now, we'll handle this in the foreground handler
      print('FCM Background: Wallpaper sync will be handled when app opens');
    } catch (e) {
      print('FCM Background: Error: $e');
    }
  }
}

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase;

  FCMService({required SupabaseClient supabase}) : _supabase = supabase;

  // Initialize FCM
  Future<void> initialize() async {
    print('FCMService: Initializing...');

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('FCMService: Permission status: ${settings.authorizationStatus}');

    // Get FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      print('FCMService: Got FCM token: ${token.substring(0, 20)}...');
      await _saveFCMToken(token);
    } else {
      print('FCMService: Failed to get FCM token');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveFCMToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle messages when app is opened from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('FCMService: App opened from terminated state with message');
      _handleMessage(initialMessage);
    }

    // Handle messages when app is in background and user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    print('FCMService: Initialization complete');
  }

  Future<void> _saveFCMToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      print('FCMService: No user logged in, cannot save FCM token');
      return;
    }

    try {
      await _supabase
          .from('users')
          .update({'fcm_token': token})
          .eq('id', user.id);

      print('FCMService: FCM token saved to database');
    } catch (e) {
      print('FCMService: Error saving FCM token: $e');
    }
  }

  void _handleMessage(RemoteMessage message) {
    print('FCMService: Received message: ${message.messageId}');
    print('FCMService: Data: ${message.data}');

    if (message.data['type'] == 'wallpaper_sync') {
      final wallpaperId = message.data['wallpaper_id'];
      print('FCMService: Wallpaper sync message received for ID: $wallpaperId');

      // Trigger wallpaper application
      _applyWallpaper(wallpaperId);
    }
  }

  Future<void> _applyWallpaper(String wallpaperId) async {
    print('FCMService: Applying wallpaper ID: $wallpaperId');

    try {
      // Get wallpaper details
      final wallpaperData = await _supabase
          .from('wallpapers')
          .select()
          .eq('id', wallpaperId)
          .single();

      final wallpaper = Wallpaper.fromJson(wallpaperData);

      print('FCMService: Wallpaper details retrieved');
      print('  Image URL: ${wallpaper.imageUrl}');
      print('  Apply to: ${wallpaper.applyTo}');
      print('  Status: ${wallpaper.status}');

      // Determine if we should apply the wallpaper
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        print('FCMService: No user logged in, cannot apply wallpaper');
        return;
      }

      // Only apply if:
      // 1. Apply to is 'partner' and current user is NOT the sender
      // 2. Apply to is 'both'
      final shouldApply = wallpaper.applyTo == 'both' ||
          (wallpaper.applyTo == 'partner' && wallpaper.senderId != currentUser.id);

      if (!shouldApply) {
        print('FCMService: Not applying wallpaper (sender setting their own or partner-only for sender)');
        return;
      }

      // Apply wallpaper (Android only for now)
      if (Platform.isAndroid) {
        print('FCMService: Setting wallpaper on Android...');
        await WallpaperManagerService.setWallpaper(wallpaper.imageUrl);

        // Mark as applied
        await _supabase.from('wallpapers').update({
          'status': 'applied',
          'applied_at': DateTime.now().toIso8601String(),
        }).eq('id', wallpaperId);

        print('FCMService: Wallpaper applied successfully');
      } else if (Platform.isIOS) {
        print('FCMService: iOS wallpaper setting not implemented yet');
        // TODO: Implement iOS flow with notification → preview → save to photos
      }
    } catch (e) {
      print('FCMService: Error applying wallpaper: $e');

      // Mark as failed
      try {
        await _supabase.from('wallpapers').update({
          'status': 'failed',
        }).eq('id', wallpaperId);
      } catch (updateError) {
        print('FCMService: Error updating wallpaper status: $updateError');
      }
    }
  }

  // Manually trigger wallpaper application (for testing or retry)
  Future<void> retryApplyWallpaper(String wallpaperId) async {
    await _applyWallpaper(wallpaperId);
  }
}
