import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/login_screen.dart';
import 'package:twain/screens/home_screen.dart';
import 'package:twain/screens/onboarding_screen.dart';
import 'package:twain/services/onboarding_service.dart';
import 'package:twain/widgets/pair_monitor.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final _onboardingService = OnboardingService();
  bool? _hasCompletedOnboarding;
  bool _isCheckingOnboarding = true;
  bool _hasHandledAuthError = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = await _onboardingService.hasCompletedOnboarding();
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = completed;
        _isCheckingOnboarding = false;
      });
    }
  }

  void _onOnboardingComplete() {
    setState(() {
      _hasCompletedOnboarding = true;
    });
  }

  Future<void> _handleAuthError() async {
    if (_hasHandledAuthError) return;
    _hasHandledAuthError = true;

    // Clear stale cached data that may have been restored from Android backup.
    // This ensures a clean state when switching between debug/release builds.
    try {
      final dbService = ref.read(databaseServiceProvider);
      await dbService.clearAllData();
      await _onboardingService.resetOnboarding();
      log('AuthGate: Cleared stale data after auth error');

      if (mounted) {
        setState(() {
          _hasCompletedOnboarding = false;
        });
      }
    } catch (e) {
      log('AuthGate: Error clearing stale data: $e');
    }
  }

  Widget _buildUnauthenticatedFlow() {
    log('User is not logged in');
    // Check if onboarding is completed
    if (_hasCompletedOnboarding == false) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(twainUserProvider);

    // Show loading while checking onboarding status
    if (_isCheckingOnboarding) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return userState.when(
      data: (user) {
        if (user != null) {
          log('User is logged in');
          // Always show home screen when logged in
          // HomeScreen will handle paired vs unpaired UI
          return const PairMonitor(child: HomeScreen());
        } else {
          return _buildUnauthenticatedFlow();
        }
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) {
        // Log the error for debugging but treat as unauthenticated state.
        // This handles cases like stale auth data restored from Android backup
        // after switching from debug to release builds.
        log('AuthGate: Error in user stream: $error');

        // Clear stale data to ensure clean state on next app launch
        _handleAuthError();

        return _buildUnauthenticatedFlow();
      },
    );
  }
}