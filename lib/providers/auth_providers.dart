import 'package:twain/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/models/twain_user.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final firebaseUserProvider = StreamProvider.autoDispose((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.userChanges;
});

final twainUserProvider = StreamProvider.autoDispose<TwainUser?>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.twainUserStream();
});