import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:twain/services/fcm_service.dart';
import 'package:twain/supabase_config.dart';
import 'package:twain/config/api_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  // Validate API keys
  ApiConfig.validateKeys();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Initialize Google Sign-In
  await GoogleSignIn.instance.initialize(
    clientId: Platform.isIOS ? SupabaseConfig.googleClientIdIOS : null,
    serverClientId: SupabaseConfig.googleWebClientId, // Use Web Client ID for both platforms
  );

  runApp(const ProviderScope(child: MyApp()));
}
