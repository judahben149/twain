import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twain/widgets/auth_gate.dart';
import 'package:twain/providers/wallpaper_providers.dart';


class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    try {
      final fcmService = ref.read(fcmServiceProvider);
      await fcmService.initialize();
      print('MyApp: FCM initialized successfully');
    } catch (e) {
      print('MyApp: Error initializing FCM: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twain',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
        textTheme: GoogleFonts.jostTextTheme(),
      ),
      home: const AuthGate(),
    );
  }
}