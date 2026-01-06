import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:twain/supabase_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
