import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/services/auth_service.dart';
import 'package:twain/services/database_service.dart';
import 'package:twain/services/sticky_notes_service.dart';
import 'package:twain/services/subscription_service.dart';
import 'package:twain/models/sticky_note.dart';
import 'package:twain/models/sticky_note_reply.dart';
import 'package:twain/models/subscription_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/repositories/user_repository.dart';
import 'package:twain/repositories/sticky_notes_repository.dart';

// Database service provider (singleton)
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// User repository provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return UserRepository(
    dbService: dbService,
    supabase: Supabase.instance.client,
  );
});

// Sticky notes repository provider
final stickyNotesRepositoryProvider = Provider<StickyNotesRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return StickyNotesRepository(
    dbService: dbService,
    supabase: Supabase.instance.client,
  );
});

// Auth service provider with repository
final authServiceProvider = Provider<AuthService>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return AuthService(userRepository: userRepository);
});

final authUserProvider = StreamProvider.autoDispose((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.userChanges;
});

final twainUserProvider = StreamProvider.autoDispose<TwainUser?>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.twainUserStream();
});

// Paired user provider - streams partner data with real-time updates
final pairedUserProvider = StreamProvider.autoDispose<TwainUser?>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.pairedUserStream();
});

// Sticky Notes service provider with repository
final stickyNotesServiceProvider = Provider<StickyNotesService>((ref) {
  final repository = ref.watch(stickyNotesRepositoryProvider);
  return StickyNotesService(repository: repository);
});

// Keep sticky notes cached in memory (don't auto-dispose)
// This provides instant loading on subsequent visits
final stickyNotesStreamProvider = StreamProvider<List<StickyNote>>((ref) {
  final service = ref.watch(stickyNotesServiceProvider);
  return service.streamNotes();
});

// Stream provider for replies to a specific note (use family for per-note streams)
final stickyNoteRepliesStreamProvider =
    StreamProvider.family<List<StickyNoteReply>, String>((ref, noteId) {
  final service = ref.watch(stickyNotesServiceProvider);
  return service.streamReplies(noteId);
});

// ============================================================================
// Subscription Providers
// ============================================================================

/// Subscription service singleton provider
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService.instance;
});

/// Stream of subscription status updates
final subscriptionStatusStreamProvider = StreamProvider<SubscriptionStatus>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return service.statusStream;
});

/// Current subscription status (synchronous access)
final subscriptionStatusProvider = Provider<SubscriptionStatus>((ref) {
  final asyncStatus = ref.watch(subscriptionStatusStreamProvider);
  return asyncStatus.valueOrNull ?? SubscriptionService.instance.currentStatus;
});

/// Whether user has Twain Plus subscription
final isTwainPlusProvider = Provider<bool>((ref) {
  final status = ref.watch(subscriptionStatusProvider);
  return status.isTwainPlus;
});

/// Available subscription offerings
final subscriptionOfferingsProvider = FutureProvider<List<SubscriptionOffering>>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return service.getOfferings();
});