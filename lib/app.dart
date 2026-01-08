import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twain/navigation/app_navigator.dart';
import 'package:twain/providers/wallpaper_providers.dart';
import 'package:twain/services/notification_router.dart';
import 'package:twain/widgets/auth_gate.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final fcmService = ref.read(fcmServiceProvider);
      await fcmService.initialize();
      await NotificationRouter.initialize(ref);
    } catch (e) {
      debugPrint('MyApp: Error during initialization: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
