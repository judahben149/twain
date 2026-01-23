import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/wallpaper.dart';
import 'package:twain/services/wallpaper_manager_service.dart';
import 'package:twain/supabase_config.dart';
import 'package:wallpaper_sync_plugin/wallpaper_sync_plugin.dart';

const _wallpaperSyncType = 'wallpaper_sync';
const _notificationsEnabledKey = 'notifications_enabled';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  print('FCM Background: Handling message: ${message.messageId}');
  if (message.data['type'] != _wallpaperSyncType) {
    return;
  }

  final supabase = await _recoverSupabaseClient();
  if (supabase == null) {
    print(
        'FCM Background: Unable to recover Supabase session for wallpaper sync');
    return;
  }

  await _processWallpaperSync(message.data, client: supabase);
}

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase;

  FCMService({required SupabaseClient supabase}) : _supabase = supabase;

  // Initialize FCM
  Future<void> initialize() async {
    print('FCMService: Initializing...');

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('FCMService: Permission status: ${settings.authorizationStatus}');

    final token = await _messaging.getToken();
    if (token != null) {
      print('FCMService: Got FCM token: ${token.substring(0, 20)}...');
      await _saveFCMToken(token);
    } else {
      print('FCMService: Failed to get FCM token');
    }

    _messaging.onTokenRefresh.listen((token) {
      unawaited(_saveFCMToken(token));
    });

    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleMessage(message));
    });

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleMessage(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_handleMessage(message));
    });

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
          .update({'fcm_token': token}).eq('id', user.id);
      print('FCMService: FCM token saved to database');
    } catch (e) {
      print('FCMService: Error saving FCM token: $e');
    }
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    print('FCMService: Received message: ${message.messageId}');
    print('FCMService: Data: ${message.data}');

    if (message.data['type'] != _wallpaperSyncType) {
      return;
    }

    await _processWallpaperSync(message.data, client: _supabase);
  }

  // Manually trigger wallpaper application (for testing or retry)
  Future<void> retryApplyWallpaper(String wallpaperId) {
    return _processWallpaperSync(
      {
        'type': _wallpaperSyncType,
        'wallpaper_id': wallpaperId,
      },
      client: _supabase,
    );
  }
}

Future<SupabaseClient?> _recoverSupabaseClient() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final session = prefs.getString(_supabasePersistedSessionKey);
    if (session == null || session.isEmpty) {
      print('Wallpaper Sync: No persisted Supabase session found.');
      return null;
    }

    final client = SupabaseClient(
      SupabaseConfig.supabaseUrl,
      SupabaseConfig.supabaseAnonKey,
    );

    await client.auth.recoverSession(session);
    return client;
  } catch (error) {
    print('Wallpaper Sync: Failed to recover Supabase session: $error');
    return null;
  }
}

String get _supabasePersistedSessionKey {
  final host = Uri.parse(SupabaseConfig.supabaseUrl).host;
  final projectRef = host.split('.').first;
  return 'sb-$projectRef-auth-token';
}

Future<void> _processWallpaperSync(
  Map<String, dynamic> data, {
  required SupabaseClient client,
}) async {
  final wallpaperId = data['wallpaper_id'] as String?;
  if (wallpaperId == null) {
    print(
      'Wallpaper Sync: Missing wallpaper_id in payload: ${jsonEncode(data)}',
    );
    return;
  }

  // Try to build wallpaper from payload first (faster - no network call)
  Wallpaper? wallpaper = _wallpaperFromPayload(wallpaperId, data);

  // Only fetch from Supabase if payload didn't have enough data
  if (wallpaper == null) {
    try {
      final response = await client
          .from('wallpapers')
          .select()
          .eq('id', wallpaperId)
          .maybeSingle();

      if (response != null) {
        wallpaper = Wallpaper.fromJson(response);
      }
    } catch (error) {
      print(
        'Wallpaper Sync: Failed to fetch wallpaper $wallpaperId from Supabase: $error',
      );
    }
  }

  if (wallpaper == null) {
    print(
        'Wallpaper Sync: Unable to resolve wallpaper payload for id $wallpaperId');
    return;
  }

  final currentUser = client.auth.currentUser;
  if (currentUser == null) {
    print('Wallpaper Sync: No authenticated user – skipping apply.');
    return;
  }

  final shouldApply = _shouldApplyWallpaper(wallpaper, currentUser.id);
  if (!shouldApply) {
    print(
        'Wallpaper Sync: Conditions not met to apply wallpaper ${wallpaper.id}');
    return;
  }

  // Check if notifications are enabled before showing
  final notificationsEnabled = await _areNotificationsEnabled();
  if (notificationsEnabled) {
    // Use sender_name from payload if available, otherwise look it up
    final payloadSenderName = data['sender_name'] as String?;
    final senderName = (payloadSenderName != null && payloadSenderName.isNotEmpty)
        ? payloadSenderName
        : await _lookupSenderName(client, wallpaper.senderId);
    final isSender = wallpaper.senderId == currentUser.id;
    final partnerFirstName = senderName != null
        ? _firstName(senderName)
        : 'Your partner';
    final notificationBody = isSender
        ? 'Your wallpaper was just applied.'
        : '$partnerFirstName has set a new wallpaper for you.';
    final notificationTitle =
        isSender ? 'Wallpaper updated' : 'New wallpaper from $partnerFirstName';

    try {
      await WallpaperSyncPlugin.showNotification(
        title: notificationTitle,
        body: notificationBody,
      );
    } catch (error) {
      print('Wallpaper Sync: Failed to show notification: $error');
    }
  } else {
    print('Wallpaper Sync: Notifications disabled by user preference');
  }

  if (!Platform.isAndroid) {
    print(
        'Wallpaper Sync: Wallpaper auto-apply currently only supported on Android.');
    return;
  }

  try {
    print('Wallpaper Sync: ========== APPLYING WALLPAPER ==========');
    print('Wallpaper Sync: Wallpaper ID: ${wallpaper.id}');
    print('Wallpaper Sync: Image URL: ${wallpaper.imageUrl}');
    print('Wallpaper Sync: Source type: ${wallpaper.sourceType}');
    print('Wallpaper Sync: Sender ID: ${wallpaper.senderId}');
    await WallpaperManagerService.setWallpaper(wallpaper.imageUrl);
    await client.from('wallpapers').update({
      'status': 'applied',
      'applied_at': DateTime.now().toIso8601String(),
    }).eq('id', wallpaper.id);
    print('Wallpaper Sync: Wallpaper ${wallpaper.id} applied successfully');
    print('Wallpaper Sync: ========================================');
  } catch (error) {
    print('Wallpaper Sync: Failed to apply wallpaper ${wallpaper.id}: $error');
    try {
      await client
          .from('wallpapers')
          .update({'status': 'failed'}).eq('id', wallpaper.id);
    } catch (updateError) {
      print('Wallpaper Sync: Failed to update wallpaper status: $updateError');
    }
  }
}

Wallpaper? _wallpaperFromPayload(
  String wallpaperId,
  Map<String, dynamic> data,
) {
  final imageUrl = data['image_url'] as String?;
  final pairId = data['pair_id'] as String?;
  final senderId = data['sender_id'] as String?;

  if (imageUrl == null || pairId == null || senderId == null) {
    return null;
  }

  DateTime? appliedAt;
  final appliedAtValue = data['applied_at'];
  if (appliedAtValue is String) {
    appliedAt = DateTime.tryParse(appliedAtValue);
  }

  DateTime createdAt = DateTime.now();
  final createdAtValue = data['created_at'];
  if (createdAtValue is String) {
    createdAt = DateTime.tryParse(createdAtValue) ?? createdAt;
  }

  return Wallpaper(
    id: wallpaperId,
    pairId: pairId,
    senderId: senderId,
    imageUrl: imageUrl,
    sourceType: data['source_type'] as String? ?? 'shared_board',
    applyTo: data['apply_to'] as String? ?? 'partner',
    status: data['status'] as String? ?? 'pending',
    appliedAt: appliedAt,
    createdAt: createdAt,
  );
}

bool _shouldApplyWallpaper(Wallpaper wallpaper, String currentUserId) {
  return wallpaper.applyTo == 'both' ||
      (wallpaper.applyTo == 'partner' && wallpaper.senderId != currentUserId);
}

Future<String?> _lookupSenderName(
  SupabaseClient client,
  String senderId,
) async {
  try {
    final response = await client
        .from('users')
        .select('display_name')
        .eq('id', senderId)
        .maybeSingle();
    if (response == null) return null;
    final name = response['display_name'] as String?;
    return name?.trim().isEmpty == true ? null : name?.trim();
  } catch (error) {
    print('Wallpaper Sync: Failed to fetch sender name: $error');
    return null;
  }
}

String _firstName(String name) {
  final parts =
      name.split(' ').where((part) => part.trim().isNotEmpty).toList();
  return parts.isEmpty ? name : parts.first;
}

Future<bool> _areNotificationsEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  } catch (error) {
    print('Wallpaper Sync: Failed to check notification preference: $error');
    return true; // Default to showing notifications if preference check fails
  }
}
