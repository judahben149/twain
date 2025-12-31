import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/login_screen.dart';
import 'package:twain/screens/home_screen.dart';
import 'package:twain/screens/pairing_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(twainUserProvider);

    return userState.when(
      data: (user) {
        if (user != null) {
          log('User is logged in');
          // Check if user has a partner
          if (user.pairId == null) {
            log('User is not paired, showing pairing screen');
            return const PairingScreen();
          } else {
            log('User is paired, showing home screen');
            return const HomeScreen();
          }
        } else {
          log('User is not logged in');
          return const LoginScreen();
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Something went wrong')),
    );
  }
}