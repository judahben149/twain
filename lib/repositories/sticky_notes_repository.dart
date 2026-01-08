import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/sticky_note.dart';
import 'package:twain/models/sticky_note_reply.dart';
import 'package:twain/services/database_service.dart';

class StickyNotesRepository {
  final DatabaseService _dbService;
  final SupabaseClient _supabase;

  StickyNotesRepository({
    required DatabaseService dbService,
    required SupabaseClient supabase,
  })  : _dbService = dbService,
        _supabase = supabase;

  Stream<List<StickyNote>> watchNotes(String pairId) {
    return Stream.multi((controller) async {
      final cached = await _dbService.getStickyNotesByPairId(pairId);
      if (!controller.isClosed) {
        controller.add(cached);
      }

      var fetchInProgress = false;
      var pendingFetch = false;

      Future<void> fetchAndEmit() async {
        if (controller.isClosed) return;
        if (fetchInProgress) {
          pendingFetch = true;
          return;
        }

        fetchInProgress = true;
        do {
          pendingFetch = false;
          try {
            final notes = await _fetchNotes(pairId);
            await _dbService.saveStickyNotes(notes);
            if (!controller.isClosed) {
              controller.add(notes);
            }
          } catch (error, stack) {
            if (!controller.isClosed) {
              controller.addError(error, stack);
            }
          }
        } while (pendingFetch && !controller.isClosed);
        fetchInProgress = false;
      }

      final notesChannel = _supabase
          .channel('sticky_notes_repo_$pairId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sticky_notes',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'pair_id',
              value: pairId,
            ),
            callback: (_) => unawaited(fetchAndEmit()),
          )
          .subscribe();

      final likesChannel = _supabase
          .channel('sticky_note_likes_repo_$pairId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sticky_note_likes',
            callback: (_) => unawaited(fetchAndEmit()),
          )
          .subscribe();

      final repliesChannel = _supabase
          .channel('sticky_note_replies_repo_$pairId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sticky_note_replies',
            callback: (_) => unawaited(fetchAndEmit()),
          )
          .subscribe();

      await fetchAndEmit();

      controller.onCancel = () async {
        try {
          await _supabase.removeChannel(notesChannel);
        } catch (_) {}
        try {
          await _supabase.removeChannel(likesChannel);
        } catch (_) {}
        try {
          await _supabase.removeChannel(repliesChannel);
        } catch (_) {}
      };
    });
  }

  Stream<List<StickyNoteReply>> watchReplies(String noteId) {
    return Stream.multi((controller) async {
      final cached = await _dbService.getRepliesByNoteId(noteId);
      if (!controller.isClosed) {
        controller.add(cached);
      }

      var fetchInProgress = false;
      var pendingFetch = false;

      Future<void> fetchAndEmit() async {
        if (controller.isClosed) return;
        if (fetchInProgress) {
          pendingFetch = true;
          return;
        }

        fetchInProgress = true;
        do {
          pendingFetch = false;
          try {
            final replies = await _fetchReplies(noteId);
            await _dbService.saveStickyNoteReplies(replies);
            if (!controller.isClosed) {
              controller.add(replies);
            }
          } catch (error, stack) {
            if (!controller.isClosed) {
              controller.addError(error, stack);
            }
          }
        } while (pendingFetch && !controller.isClosed);

        fetchInProgress = false;
      }

      final repliesChannel = _supabase
          .channel('sticky_note_replies_stream_$noteId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sticky_note_replies',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'note_id',
              value: noteId,
            ),
            callback: (_) => unawaited(fetchAndEmit()),
          )
          .subscribe();

      await fetchAndEmit();

      controller.onCancel = () async {
        try {
          await _supabase.removeChannel(repliesChannel);
        } catch (_) {}
      };
    });
  }

  Future<List<StickyNote>> _fetchNotes(String pairId) async {
    final data = await _supabase
        .from('sticky_notes')
        .select()
        .eq('pair_id', pairId)
        .order('created_at', ascending: false);

    if (data.isEmpty) return [];

    final senderIds = <String>{};
    final noteIds = <String>[];

    for (final row in data) {
      final map = Map<String, dynamic>.from(row as Map);
      noteIds.add(map['id'] as String);
      final senderId = map['sender_id'] as String?;
      if (senderId != null) senderIds.add(senderId);
    }

    final senderById = <String, Map<String, dynamic>>{};
    if (senderIds.isNotEmpty) {
      final senders = await _supabase
          .from('users')
          .select('id, display_name, avatar_url')
          .inFilter('id', senderIds.toList());
      for (final row in senders) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id'] as String?;
        if (id != null) {
          senderById[id] = map;
        }
      }
    }

    final likedBy = <String, Set<String>>{};
    if (noteIds.isNotEmpty) {
      final likes = await _supabase
          .from('sticky_note_likes')
          .select('note_id, user_id')
          .inFilter('note_id', noteIds);
      for (final row in likes) {
        final map = Map<String, dynamic>.from(row as Map);
        final noteId = map['note_id'] as String?;
        final userId = map['user_id'] as String?;
        if (noteId == null || userId == null) continue;
        likedBy.putIfAbsent(noteId, () => <String>{}).add(userId);
      }
    }

    final repliesCount = <String, int>{};
    if (noteIds.isNotEmpty) {
      final replies = await _supabase
          .from('sticky_note_replies')
          .select('note_id')
          .inFilter('note_id', noteIds);
      for (final row in replies) {
        final map = Map<String, dynamic>.from(row as Map);
        final noteId = map['note_id'] as String?;
        if (noteId == null) continue;
        repliesCount[noteId] = (repliesCount[noteId] ?? 0) + 1;
      }
    }

    return data.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final noteId = map['id'] as String;
      final senderId = map['sender_id'] as String;
      final sender = senderById[senderId];
      final likedUsers = likedBy[noteId];

      return StickyNote(
        id: noteId,
        pairId: map['pair_id'] as String,
        senderId: senderId,
        senderName: sender?['display_name'] as String?,
        message: map['message'] as String,
        color: map['color'] as String? ?? 'FFF9C4',
        likedByUserIds:
            likedUsers != null ? List<String>.from(likedUsers) : const [],
        replyCount: repliesCount[noteId] ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
    }).toList();
  }

  Future<List<StickyNoteReply>> _fetchReplies(String noteId) async {
    final data = await _supabase
        .from('sticky_note_replies')
        .select()
        .eq('note_id', noteId)
        .order('created_at', ascending: true);

    if (data.isEmpty) return [];

    final senderIds = <String>{};
    for (final row in data) {
      final map = Map<String, dynamic>.from(row as Map);
      final senderId = map['sender_id'] as String?;
      if (senderId != null) senderIds.add(senderId);
    }

    final senderById = <String, String?>{};
    if (senderIds.isNotEmpty) {
      final senders = await _supabase
          .from('users')
          .select('id, display_name')
          .inFilter('id', senderIds.toList());
      for (final row in senders) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id'] as String?;
        if (id != null) {
          senderById[id] = map['display_name'] as String?;
        }
      }
    }

    return data.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final senderId = map['sender_id'] as String;
      return StickyNoteReply(
        id: map['id'] as String,
        noteId: map['note_id'] as String,
        senderId: senderId,
        senderName: senderById[senderId],
        message: map['message'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
    }).toList();
  }

  Future<List<StickyNote>> getCachedNotes(String pairId) async {
    return _dbService.getStickyNotesByPairId(pairId);
  }

  Future<void> cacheNotes(List<StickyNote> notes) async {
    await _dbService.saveStickyNotes(notes);
  }

  Future<void> cacheNote(StickyNote note) async {
    await _dbService.saveStickyNote(note);
  }

  Future<void> clearAllCache() async {
    await _dbService.clearAllStickyNotes();
  }

  Future<void> clearCacheForPair(String pairId) async {
    await _dbService.clearStickyNotesByPairId(pairId);
  }

  Future<void> deleteNoteFromCache(String noteId) async {
    await _dbService.deleteStickyNote(noteId);
  }

  Future<void> cacheReply(StickyNoteReply reply) async {
    await _dbService.saveStickyNoteReply(reply);
  }

  Future<void> deleteReplyFromCache(String replyId) async {
    await _dbService.deleteStickyNoteReply(replyId);
  }

  Future<void> clearRepliesForNote(String noteId) async {
    await _dbService.clearRepliesByNoteId(noteId);
  }
}
