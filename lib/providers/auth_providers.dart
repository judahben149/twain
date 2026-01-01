import 'package:twain/services/auth_service.dart';
import 'package:twain/services/sticky_notes_service.dart';
import 'package:twain/models/sticky_note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/models/twain_user.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authUserProvider = StreamProvider.autoDispose((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.userChanges;
});

final twainUserProvider = StreamProvider.autoDispose<TwainUser?>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.twainUserStream();
});

// Paired user provider - streams partner data whenever current user's pair_id changes
final pairedUserProvider = StreamProvider.autoDispose<TwainUser?>((ref) {
  final auth = ref.watch(authServiceProvider);

  return ref.watch(twainUserProvider.stream).asyncMap((currentUser) async {
    print('pairedUserProvider: currentUser = ${currentUser?.displayName}, pairId = ${currentUser?.pairId}');
    if (currentUser?.pairId == null) {
      print('pairedUserProvider: No pair_id, returning null');
      return null;
    }

    try {
      // Add timeout to prevent infinite loading
      final partner = await auth.getPairedUser().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('pairedUserProvider: Timeout fetching partner');
          return null;
        },
      );
      print('pairedUserProvider: Got partner = ${partner?.displayName}');
      return partner;
    } catch (e) {
      print('pairedUserProvider: Error fetching partner: $e');
      return null;
    }
  });
});

// Sticky Notes providers
final stickyNotesServiceProvider = Provider<StickyNotesService>(
  (ref) => StickyNotesService(),
);

final stickyNotesStreamProvider = StreamProvider.autoDispose<List<StickyNote>>((ref) {
  final service = ref.watch(stickyNotesServiceProvider);
  return service.streamNotes();
});