import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/login_screen.dart';
import 'package:twain/screens/home_screen.dart';
import 'package:twain/screens/welcome_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(firebaseUserProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          log('User is logged in');
          return const HomeScreen();
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