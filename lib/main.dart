import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:twain/services/fcm_service.dart';
import 'package:twain/services/subscription_service.dart';
import 'package:twain/supabase_config.dart';
import 'package:twain/config/api_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await runZonedGuarded<Future<void>>(() async {
    // Load environment variables from .env file
    await dotenv.load(fileName: ".env");

    // Validate API keys
    ApiConfig.validateKeys();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize Firebase
    await Firebase.initializeApp();

    // Configure Crashlytics
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Initialize Supabase
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );

    // Initialize Google Sign-In
    // Android: serverClientId is required for Credential Manager native UI
    // iOS: clientId is required for native sign-in
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? SupabaseConfig.googleClientIdIOS : null,
      serverClientId: SupabaseConfig.googleWebClientId,
    );

    // Initialize RevenueCat subscription service
    await SubscriptionService.instance.initialize();

    // Set user ID if already logged in
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      await SubscriptionService.instance.setUserId(currentUser.id);
    }

    runApp(const ProviderScope(child: MyApp()));
  }, (error, stack) async {
    if (Firebase.apps.isNotEmpty) {
      await FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}
