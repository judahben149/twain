import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/models/sticky_note.dart';
import 'package:twain/navigation/app_navigator.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/sticky_note_detail_screen.dart';
import 'package:twain/services/sticky_notes_service.dart';

class NotificationRouter {
  NotificationRouter._();

  static const _channelName = 'com.twain.app/navigation';
  static const MethodChannel _channel = MethodChannel(_channelName);
  static bool _initialized = false;

  static Future<void> initialize(WidgetRef ref) async {
    if (_initialized) return;
    _initialized = true;

    try {
      final payload =
          await _channel.invokeMethod<String>('consumeNotificationPayload');
      if (payload != null) {
        _handlePayload(ref, payload);
      }
    } catch (_) {}

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationTapped') {
        final payload = call.arguments as String?;
        if (payload != null) {
          _handlePayload(ref, payload);
        }
      }
      return null;
    });
  }

  static Future<void> _handlePayload(WidgetRef ref, String payload) async {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = data['type'] as String?;
    final noteId = data['noteId'] as String?;
    if (type == null || noteId == null) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    try {
      final note = await ref
          .read(stickyNotesServiceProvider)
          .fetchNoteById(noteId);
      if (note == null) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => StickyNoteDetailScreen(note: note),
        ),
      );
    } catch (error) {
      debugPrint('NotificationRouter: Failed to open sticky note $noteId: $error');
    }
  }
}
