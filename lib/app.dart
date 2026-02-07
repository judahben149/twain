import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/providers/wallpaper_providers.dart';
import 'package:twain/navigation/app_navigator.dart';
import 'package:twain/services/notification_router.dart';
import 'package:twain/widgets/auth_gate.dart';
import 'package:twain/widgets/connectivity_banner.dart';
import 'package:twain/widgets/dynamic_theme_builder.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final fcmService = ref.read(fcmServiceProvider);
      await fcmService.initialize();
      await ref.read(authServiceProvider).setPresenceOnline();
      await NotificationRouter.initialize(ref);
    } catch (e) {
      debugPrint('MyApp: Error during initialization: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authService = ref.read(authServiceProvider);
    if (state == AppLifecycleState.resumed) {
      authService.setPresenceOnline();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      authService.setPresenceAway();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicThemeBuilder(
      builder: (lightTheme, darkTheme, themeMode) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Twain',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          builder: (context, child) {
            return ConnectivityBanner(child: child ?? const SizedBox.shrink());
          },
          home: const AuthGate(),
        );
      },
    );
  }
}
