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
          log('User is not logged in');
          // Check if onboarding is completed
          if (_hasCompletedOnboarding == false) {
            return OnboardingScreen(onComplete: _onOnboardingComplete);
          }
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Something went wrong')),
      ),
    );
  }
}