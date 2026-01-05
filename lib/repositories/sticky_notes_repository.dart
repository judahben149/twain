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

  // Stream sticky notes with cache-first strategy
  Stream<List<StickyNote>> watchNotes(String pairId) async* {
    print('StickyNotesRepository: Starting watchNotes for pairId: $pairId');

    // Step 1: Immediately yield cached data
    final cachedNotes = await _dbService.getStickyNotesByPairId(pairId);
    print('StickyNotesRepository: Yielding ${cachedNotes.length} cached notes');
    yield cachedNotes;

    // Step 2: Subscribe to multiple tables using a broadcast StreamController
    final controller = StreamController<List<StickyNote>>.broadcast();

    // Helper function to fetch enriched notes with error handling
    Future<void> fetchAndEmit() async {
      try {
        final data = await _supabase
            .from('sticky_notes')
            .select()
            .eq('pair_id', pairId)
            .order('created_at', ascending: false);

        final enrichedNotes = await Future.wait(
          data.map((noteData) async {
            // Get sender name and avatar
            final senderData = await _supabase
                .from('users')
                .select('display_name, avatar_url')
                .eq('id', noteData['sender_id'])
                .maybeSingle();

            // Get likes with user info
            final likesData = await _supabase
                .from('sticky_note_likes')
                .select('user_id')
                .eq('note_id', noteData['id']);

            final likedByUserIds = likesData
                .map((like) => like['user_id'] as String)
                .toList();

            // Get reply count
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

        final notes = enrichedNotes.map((json) => StickyNote.fromJson(json)).toList();
        await _dbService.saveStickyNotes(notes);

        if (!controller.isClosed) {
          controller.add(notes);
        }
      } catch (e) {
        print('StickyNotesRepository: Error fetching notes: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Subscribe to sticky_notes changes
    _supabase
        .channel('sticky_notes_$pairId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sticky_notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pair_id',
            value: pairId,
          ),
          callback: (payload) {
            print('StickyNotesRepository: Notes table changed - ${payload.eventType}');
            fetchAndEmit();
          },
        )
        .subscribe();

    // Subscribe to sticky_note_likes changes
    _supabase
        .channel('sticky_note_likes_$pairId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sticky_note_likes',
          callback: (payload) {
            print('StickyNotesRepository: Likes table changed - ${payload.eventType}');
            fetchAndEmit();
          },
        )
        .subscribe();

    // Subscribe to sticky_note_replies changes
    _supabase
        .channel('sticky_note_replies_$pairId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sticky_note_replies',
          callback: (payload) {
            print('StickyNotesRepository: Replies table changed - ${payload.eventType}');
            fetchAndEmit();
          },
        )
        .subscribe();

    // Initial fetch after subscriptions are set up
    await fetchAndEmit();

    // Yield from controller stream
    yield* controller.stream;
  }

  // Get cached notes (one-time fetch, no streaming)
  Future<List<StickyNote>> getCachedNotes(String pairId) async {
    return await _dbService.getStickyNotesByPairId(pairId);
  }

  // Cache notes manually
  Future<void> cacheNotes(List<StickyNote> notes) async {
    await _dbService.saveStickyNotes(notes);
  }

  // Cache a single note
  Future<void> cacheNote(StickyNote note) async {
    await _dbService.saveStickyNote(note);
  }

  // Clear all cached notes
  Future<void> clearAllCache() async {
    print('StickyNotesRepository: Clearing all sticky notes cache');
    await _dbService.clearAllStickyNotes();
  }

  // Clear notes for a specific pair
  Future<void> clearCacheForPair(String pairId) async {
    print('StickyNotesRepository: Clearing cache for pair $pairId');
    await _dbService.clearStickyNotesByPairId(pairId);
  }

  // Delete a single note from cache
  Future<void> deleteNoteFromCache(String noteId) async {
    await _dbService.deleteStickyNote(noteId);
  }

  // Stream replies for a specific note with cache-first strategy
  Stream<List<StickyNoteReply>> watchReplies(String noteId) async* {
    print('StickyNotesRepository: Starting watchReplies for noteId: $noteId');

    // Step 1: Immediately yield cached replies
    final cachedReplies = await _dbService.getRepliesByNoteId(noteId);
    print('StickyNotesRepository: Yielding ${cachedReplies.length} cached replies');
    yield cachedReplies;

    // Step 2: Use broadcast controller for real-time updates
    final controller = StreamController<List<StickyNoteReply>>.broadcast();

    // Helper function to fetch and emit replies
    Future<void> fetchAndEmitReplies() async {
      try {
        final data = await _supabase
            .from('sticky_note_replies')
            .select()
            .eq('note_id', noteId)
            .order('created_at', ascending: true);

        print('StickyNotesRepository: Fetched ${data.length} replies for note $noteId');

        // Fetch sender names for all replies
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

        // Convert to StickyNoteReply objects
        final replies = repliesWithNames
            .map((json) => StickyNoteReply.fromJson(json))
            .toList();

        // Cache all replies
        await _dbService.saveStickyNoteReplies(replies);
        print('StickyNotesRepository: Updated cache with ${replies.length} replies');

        if (!controller.isClosed) {
          controller.add(replies);
        }
      } catch (error) {
        print('StickyNotesRepository: Error fetching replies: $error');
        if (!controller.isClosed) {
          controller.addError(error);
        }
      }
    }

    // Subscribe to sticky_note_replies changes
    _supabase
        .channel('replies_$noteId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sticky_note_replies',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'note_id',
            value: noteId,
          ),
          callback: (payload) {
            print('StickyNotesRepository: Replies changed for note $noteId - ${payload.eventType}');
            fetchAndEmitReplies();
          },
        )
        .subscribe();

    // Initial fetch
    await fetchAndEmitReplies();

    // Yield from controller stream
    yield* controller.stream;
  }

  // Cache a single reply
  Future<void> cacheReply(StickyNoteReply reply) async {
    await _dbService.saveStickyNoteReply(reply);
  }

  // Delete a reply from cache
  Future<void> deleteReplyFromCache(String replyId) async {
    await _dbService.deleteStickyNoteReply(replyId);
  }

  // Clear all replies for a note from cache
  Future<void> clearRepliesForNote(String noteId) async {
    await _dbService.clearRepliesByNoteId(noteId);
  }
}
