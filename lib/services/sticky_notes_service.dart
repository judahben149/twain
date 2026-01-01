import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/sticky_note.dart';

class StickyNotesService {
  final _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get current user's pair_id
  Future<String?> _getPairId() async {
    final user = currentUser;
    if (user == null) return null;

    final userData = await _supabase
        .from('users')
        .select('pair_id')
        .eq('id', user.id)
        .single();

    return userData['pair_id'] as String?;
  }

  // Stream of sticky notes for the current user's pair
  Stream<List<StickyNote>> streamNotes() async* {
    final pairId = await _getPairId();

    if (pairId == null) {
      print('No pair_id found, returning empty stream');
      yield [];
      return;
    }

    print('Streaming sticky notes for pair: $pairId');

    await for (final data in _supabase
        .from('sticky_notes')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('created_at', ascending: false)) {
      print('Sticky notes stream emitted: ${data.length} notes');

      // Fetch sender names for all notes
      final notesWithNames = await Future.wait(
        data.map((noteData) async {
          final senderData = await _supabase
              .from('users')
              .select('display_name')
              .eq('id', noteData['sender_id'])
              .maybeSingle();

          return {
            ...noteData,
            'sender_name': senderData?['display_name'],
          };
        }).toList(),
      );

      yield notesWithNames
          .map((json) => StickyNote.fromJson(json as Map<String, dynamic>))
          .toList();
    }
  }

  // Create a new sticky note
  Future<void> createNote(String message) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    // Get current user's pair_id
    final userData = await _supabase
        .from('users')
        .select('pair_id')
        .eq('id', user.id)
        .single();

    final pairId = userData['pair_id'] as String?;
    if (pairId == null) throw Exception('No pair found');

    print('Creating sticky note for pair: $pairId');

    await _supabase.from('sticky_notes').insert({
      'pair_id': pairId,
      'sender_id': user.id,
      'message': message,
      'is_liked': false,
    });

    print('Sticky note created successfully');
  }

  // Toggle like on a sticky note
  Future<void> toggleLike(String noteId, bool isLiked) async {
    print('Toggling like for note $noteId to $isLiked');

    await _supabase.from('sticky_notes').update({
      'is_liked': isLiked,
    }).eq('id', noteId);

    print('Like toggled successfully');
  }

  // Delete a sticky note
  Future<void> deleteNote(String noteId) async {
    await _supabase.from('sticky_notes').delete().eq('id', noteId);
  }
}
