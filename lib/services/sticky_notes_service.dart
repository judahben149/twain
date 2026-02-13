import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/sticky_note.dart';
import 'package:twain/models/sticky_note_reply.dart';
import 'package:twain/repositories/sticky_notes_repository.dart';

class StickyNotesService {
  final _supabase = Supabase.instance.client;
  final StickyNotesRepository? _repository;

  StickyNotesService({StickyNotesRepository? repository})
      : _repository = repository;

  User? get currentUser => _supabase.auth.currentUser;

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

  Stream<List<StickyNote>> streamNotes() async* {
    final pairId = await _getPairId();

    if (pairId == null) {
      yield [];
      return;
    }

    if (_repository != null) {
      yield* _repository.watchNotes(pairId);
      return;
    }

    // Fallback to direct Supabase (without repository)
    final controller = StreamController<List<StickyNote>>();

    Future<List<StickyNote>> fetchNotes() async {
      final data = await _supabase
          .from('sticky_notes')
          .select()
          .eq('pair_id', pairId)
          .order('created_at', ascending: false);

      final enriched = await Future.wait(
        data.map((row) async {
          final senderData = await _supabase
              .from('users')
              .select('display_name, avatar_url')
              .eq('id', row['sender_id'])
              .maybeSingle();

          final likesData = await _supabase
              .from('sticky_note_likes')
              .select('user_id')
              .eq('note_id', row['id']);

          final repliesData = await _supabase
              .from('sticky_note_replies')
              .select('id')
              .eq('note_id', row['id']);

          return {
            ...row,
            'sender_name': senderData?['display_name'],
            'liked_by_user_ids':
                likesData.map((like) => like['user_id'] as String).toList(),
            'reply_count': repliesData.length,
          };
        }),
      );

      return enriched.map((json) => StickyNote.fromJson(json)).toList();
    }

    final notesChannel = _supabase.channel('notes_$pairId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sticky_notes',
      callback: (_) async {
        controller.add(await fetchNotes());
      },
    ).subscribe();

    final likesChannel = _supabase.channel('likes_$pairId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sticky_note_likes',
      callback: (_) async {
        controller.add(await fetchNotes());
      },
    ).subscribe();

    controller.onCancel = () async {
      await _supabase.removeChannel(notesChannel);
      await _supabase.removeChannel(likesChannel);
      await controller.close();
    };

    controller.add(await fetchNotes());

    yield* controller.stream;
  }

  Future<void> createNote(String message, {String color = 'FFF9C4'}) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    final userData = await _supabase
        .from('users')
        .select('pair_id')
        .eq('id', user.id)
        .single();

    final pairId = userData['pair_id'] as String?;
    if (pairId == null) throw Exception('No pair found');

    await _supabase.from('sticky_notes').insert({
      'pair_id': pairId,
      'sender_id': user.id,
      'message': message,
      'color': color,
    });
  }

  Future<void> toggleLike(String noteId) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    final existingLike = await _supabase
        .from('sticky_note_likes')
        .select('id')
        .eq('note_id', noteId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existingLike != null) {
      await _supabase
          .from('sticky_note_likes')
          .delete()
          .eq('note_id', noteId)
          .eq('user_id', user.id);
    } else {
      await _supabase.from('sticky_note_likes').insert({
        'note_id': noteId,
        'user_id': user.id,
      });
    }
  }

  Future<void> deleteNote(String noteId) async {
    await _supabase.from('sticky_notes').delete().eq('id', noteId);
  }

  Stream<List<StickyNoteReply>> streamReplies(String noteId) async* {
    if (_repository != null) {
      yield* _repository.watchReplies(noteId);
      return;
    }

    final stream = _supabase
        .from('sticky_note_replies')
        .stream(primaryKey: ['id'])
        .eq('note_id', noteId)
        .order('created_at', ascending: true);

    yield* stream.map((data) {
      return data.map((reply) => StickyNoteReply.fromJson({
            ...reply,
            'sender_name': null,
          })).toList();
    });
  }

  Future<void> createReply(String noteId, String message) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    await _supabase.from('sticky_note_replies').insert({
      'note_id': noteId,
      'sender_id': user.id,
      'message': message,
    });
  }

  Future<StickyNote?> fetchNoteById(String noteId) async {
    final data = await _supabase
        .from('sticky_notes')
        .select()
        .eq('id', noteId)
        .maybeSingle();
    if (data == null) return null;

    final map = Map<String, dynamic>.from(data as Map);
    final senderId = map['sender_id'] as String;
    final senderData = await _supabase
        .from('users')
        .select('display_name, avatar_url')
        .eq('id', senderId)
        .maybeSingle();

    final likes = await _supabase
        .from('sticky_note_likes')
        .select('user_id')
        .eq('note_id', noteId);

    final replies = await _supabase
        .from('sticky_note_replies')
        .select('id')
        .eq('note_id', noteId);

    return StickyNote(
      id: map['id'] as String,
      pairId: map['pair_id'] as String,
      senderId: senderId,
      senderName: senderData?['display_name'] as String?,
      message: map['message'] as String,
      color: map['color'] as String? ?? 'FFF9C4',
      likedByUserIds:
          likes.map((row) => row['user_id'] as String).toList(growable: false),
      replyCount: replies.length,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

}
