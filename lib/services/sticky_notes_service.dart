import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/sticky_note.dart';
import 'package:twain/models/sticky_note_reply.dart';
import 'package:twain/repositories/sticky_notes_repository.dart';

class StickyNotesService {
  final _supabase = Supabase.instance.client;
  final StickyNotesRepository? _repository;

  StickyNotesService({StickyNotesRepository? repository}) : _repository = repository;

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

    // If repository is available, use cache-first strategy
    if (_repository != null) {
      print('StickyNotesService: Using repository with cache-first strategy');
      yield* _repository.watchNotes(pairId);
    } else {
      // Fallback to direct Supabase (without repository)
      print('StickyNotesService: No repository, using direct Supabase');

      // Use the same channel-based approach as repository
      final controller = StreamController<List<StickyNote>>();

      Future<List<StickyNote>> fetchNotes() async {
        final data = await _supabase
            .from('sticky_notes')
            .select()
            .eq('pair_id', pairId)
            .order('created_at', ascending: false);

        final enrichedNotes = await Future.wait(
          data.map((noteData) async {
            final senderData = await _supabase
                .from('users')
                .select('display_name, avatar_url')
                .eq('id', noteData['sender_id'])
                .maybeSingle();

            final likesData = await _supabase
                .from('sticky_note_likes')
                .select('user_id')
                .eq('note_id', noteData['id']);

            final likedByUserIds = likesData
                .map((like) => like['user_id'] as String)
                .toList();

            final repliesData = await _supabase
                .from('sticky_note_replies')
                .select('id')
                .eq('note_id', noteData['id']);

            return {
              ...noteData,
              'sender_name': senderData?['display_name'],
              'liked_by_user_ids': likedByUserIds,
              'reply_count': repliesData.length,
            };
          }).toList(),
        );

        return enrichedNotes.map((json) => StickyNote.fromJson(json)).toList();
      }

      // Subscribe to all relevant tables
      _supabase.channel('notes_$pairId').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'sticky_notes',
        callback: (payload) async {
          controller.add(await fetchNotes());
        },
      ).subscribe();

      _supabase.channel('likes_$pairId').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'sticky_note_likes',
        callback: (payload) async {
          controller.add(await fetchNotes());
        },
      ).subscribe();

      controller.add(await fetchNotes());

      await for (final notes in controller.stream) {
        yield notes;
      }
    }
  }

  // Create a new sticky note
  Future<void> createNote(String message, {String color = 'FFF9C4'}) async {
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

    print('Creating sticky note for pair: $pairId with color: $color');

    await _supabase.from('sticky_notes').insert({
      'pair_id': pairId,
      'sender_id': user.id,
      'message': message,
      'color': color,
    });

    print('Sticky note created successfully');
  }

  // Toggle like on a sticky note
  Future<void> toggleLike(String noteId) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    print('Toggling like for note $noteId by user ${user.id}');

    // Check if user has already liked this note
    final existingLike = await _supabase
        .from('sticky_note_likes')
        .select('id')
        .eq('note_id', noteId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existingLike != null) {
      // Unlike: remove the like
      print('Removing like');
      await _supabase
          .from('sticky_note_likes')
          .delete()
          .eq('note_id', noteId)
          .eq('user_id', user.id);
    } else {
      // Like: add a like
      print('Adding like');
      await _supabase.from('sticky_note_likes').insert({
        'note_id': noteId,
        'user_id': user.id,
      });
    }

    print('Like toggled successfully');
  }

  // Delete a sticky note
  Future<void> deleteNote(String noteId) async {
    await _supabase.from('sticky_notes').delete().eq('id', noteId);
  }

  // Stream replies for a specific note
  Stream<List<StickyNoteReply>> streamReplies(String noteId) async* {
    print('Streaming replies for note: $noteId');

    // If repository is available, use cache-first strategy
    if (_repository != null) {
      print('StickyNotesService: Using repository for replies');
      yield* _repository.watchReplies(noteId);
    } else {
      // Fallback to direct Supabase stream
      print('StickyNotesService: No repository, using direct Supabase stream for replies');

      await for (final data in _supabase
          .from('sticky_note_replies')
          .stream(primaryKey: ['id'])
          .eq('note_id', noteId)
          .order('created_at', ascending: true)) {
        print('Reply stream emitted: ${data.length} replies');

        // Fetch sender names
        final repliesWithNames = await Future.wait(
          data.map((replyData) async {
            final senderData = await _supabase
                .from('users')
                .select('display_name')
                .eq('id', replyData['sender_id'])
                .maybeSingle();

            return {
              ...replyData,
              'sender_name': senderData?['display_name'],
            };
          }).toList(),
        );

        yield repliesWithNames
            .map((json) => StickyNoteReply.fromJson(json))
            .toList();
      }
    }
  }

  // Create a reply to a sticky note
  Future<void> createReply(String noteId, String message) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    print('Creating reply for note: $noteId');

    await _supabase.from('sticky_note_replies').insert({
      'note_id': noteId,
      'sender_id': user.id,
      'message': message,
    });

    print('Reply created successfully');
  }

  // Delete a reply
  Future<void> deleteReply(String replyId) async {
    await _supabase.from('sticky_note_replies').delete().eq('id', replyId);
  }
}
