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
      print('StickyNotesRepository: Starting watchNotes for pairId: $pairId');

      if (!controller.isClosed) {
        final cached = await _dbService.getStickyNotesByPairId(pairId);
        print(
          'StickyNotesRepository: Yielding ${cached.length} cached notes',
        );
        controller.add(cached);
      }

      var isFetching = false;
      var hasPendingFetch = false;

      Future<void> fetchAndEmit() async {
        if (controller.isClosed) return;
        if (isFetching) {
          hasPendingFetch = true;
          return;
        }

        isFetching = true;
        do {
          hasPendingFetch = false;
          try {
            final noteRows = await _supabase
                .from('sticky_notes')
                .select()
                .eq('pair_id', pairId)
                .order('created_at', ascending: false);

            final noteIds = <String>[];
            final senderIds = <String>{};

            for (final row in noteRows) {
              final id = row['id'] as String?;
              final senderId = row['sender_id'] as String?;
              if (id != null) {
                noteIds.add(id);
              }
              if (senderId != null) {
                senderIds.add(senderId);
              }
            }

            final senderById = <String, Map<String, dynamic>>{};
            if (senderIds.isNotEmpty) {
              final senders = await _supabase
                  .from('users')
                  .select('id, display_name, avatar_url')
                  .inFilter('id', senderIds.toList());

              for (final sender in senders) {
                final id = sender['id'] as String?;
                if (id != null) {
                  senderById[id] = sender;
                }
              }
            }

            final likesByNote = <String, Set<String>>{};
            if (noteIds.isNotEmpty) {
              final likes = await _supabase
                  .from('sticky_note_likes')
                  .select('note_id, user_id')
                  .inFilter('note_id', noteIds);

              for (final like in likes) {
                final noteId = like['note_id'] as String?;
                final userId = like['user_id'] as String?;
                if (noteId == null || userId == null) continue;
                likesByNote.putIfAbsent(noteId, () => <String>{}).add(userId);
              }
            }

            final repliesCountByNote = <String, int>{};
            if (noteIds.isNotEmpty) {
              final replies = await _supabase
                  .from('sticky_note_replies')
                  .select('note_id')
                  .inFilter('note_id', noteIds);

              for (final reply in replies) {
                final noteId = reply['note_id'] as String?;
                if (noteId == null) continue;
                repliesCountByNote[noteId] =
                    (repliesCountByNote[noteId] ?? 0) + 1;
              }
            }

            final notes = noteRows.map((row) {
              final id = row['id'] as String;
              final senderId = row['sender_id'] as String;
              final sender = senderById[senderId];
              final likedBy = likesByNote[id];

              return StickyNote(
                id: id,
                pairId: row['pair_id'] as String,
                senderId: senderId,
                senderName: sender?['display_name'] as String?,
                message: row['message'] as String,
                color: row['color'] as String? ?? 'FFF9C4',
                likedByUserIds:
                    likedBy?.toList(growable: false) ?? const <String>[],
                replyCount: repliesCountByNote[id] ?? 0,
                createdAt: DateTime.parse(row['created_at'] as String),
                updatedAt: DateTime.parse(row['updated_at'] as String),
              );
            }).toList();

            await _dbService.saveStickyNotes(notes);
            if (!controller.isClosed) {
              controller.add(notes);
            }
          } catch (error, stack) {
            print('StickyNotesRepository: Error fetching notes: $error');
            if (!controller.isClosed) {
              controller.addError(error, stack);
            }
          }
        } while (hasPendingFetch && !controller.isClosed);

        isFetching = false;
      }

      final notesChannel = _supabase
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
              print(
                'StickyNotesRepository: Notes table changed - ${payload.eventType}',
              );
              unawaited(fetchAndEmit());
            },
          )
          .subscribe();

      final likesChannel = _supabase
          .channel('sticky_note_likes_watch_$pairId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sticky_note_likes',
            callback: (payload) {
              print(
                'StickyNotesRepository: Likes table changed - ${payload.eventType}',
              );
              unawaited(fetchAndEmit());
            },
          )
          .subscribe();

      final repliesChannel = _supabase
          .channel('sticky_note_replies_watch_$pairId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sticky_note_replies',
            callback: (payload) {
              print(
                'StickyNotesRepository: Replies table changed - ${payload.eventType}',
              );
              unawaited(fetchAndEmit());
            },
          )
          .subscribe();

      await fetchAndEmit();

      controller.onCancel = () async {
        for (final channel in [
          notesChannel,
          likesChannel,
          repliesChannel,
        ]) {
          try {
            await _supabase.removeChannel(channel);
          } catch (error) {
            print(
              'StickyNotesRepository: Error removing channel ${channel.topic}: $error',
            );
          }
        }
      };
    });
  }

  Stream<List<StickyNoteReply>> watchReplies(String noteId) {
    return Stream.multi((controller) async {
      print('StickyNotesRepository: Starting watchReplies for noteId: $noteId');

      if (!controller.isClosed) {
        final cached = await _dbService.getRepliesByNoteId(noteId);
        print(
          'StickyNotesRepository: Yielding ${cached.length} cached replies',
        );
        controller.add(cached);
      }

      var isFetching = false;
      var hasPendingFetch = false;

      Future<void> fetchAndEmit() async {
        if (controller.isClosed) return;
        if (isFetching) {
          hasPendingFetch = true;
          return;
        }

        isFetching = true;
        do {
          hasPendingFetch = false;
          try {
            final replyRows = await _supabase
                .from('sticky_note_replies')
                .select()
                .eq('note_id', noteId)
                .order('created_at', ascending: true);

            final senderIds = <String>{};
            for (final row in replyRows) {
              final senderId = row['sender_id'] as String?;
              if (senderId != null) {
                senderIds.add(senderId);
              }
            }

            final senderNames = <String, String?>{};
            if (senderIds.isNotEmpty) {
              final senders = await _supabase
                  .from('users')
                  .select('id, display_name')
                  .inFilter('id', senderIds.toList());

              for (final sender in senders) {
                final id = sender['id'] as String?;
                if (id != null) {
                  senderNames[id] = sender['display_name'] as String?;
                }
              }
            }

            final replies = replyRows.map((row) {
              final senderId = row['sender_id'] as String;
              return StickyNoteReply(
                id: row['id'] as String,
                noteId: row['note_id'] as String,
                senderId: senderId,
                senderName: senderNames[senderId],
                message: row['message'] as String,
                createdAt: DateTime.parse(row['created_at'] as String),
                updatedAt: DateTime.parse(row['updated_at'] as String),
              );
            }).toList();

            await _dbService.saveStickyNoteReplies(replies);
            if (!controller.isClosed) {
              controller.add(replies);
            }
          } catch (error, stack) {
            print('StickyNotesRepository: Error fetching replies: $error');
            if (!controller.isClosed) {
              controller.addError(error, stack);
            }
          }
        } while (hasPendingFetch && !controller.isClosed);

        isFetching = false;
      }

      final repliesChannel = _supabase
          .channel('sticky_note_replies_$noteId')
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
              print(
                'StickyNotesRepository: Replies changed for note $noteId - ${payload.eventType}',
              );
              unawaited(fetchAndEmit());
            },
          )
          .subscribe();

      await fetchAndEmit();

      controller.onCancel = () async {
        try {
          await _supabase.removeChannel(repliesChannel);
        } catch (error) {
          print(
            'StickyNotesRepository: Error removing replies channel: $error',
          );
        }
      };
    });
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
    print('StickyNotesRepository: Clearing all sticky notes cache');
    await _dbService.clearAllStickyNotes();
  }

  Future<void> clearCacheForPair(String pairId) async {
    print('StickyNotesRepository: Clearing cache for pair $pairId');
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
