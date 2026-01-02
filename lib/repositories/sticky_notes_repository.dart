import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/sticky_note.dart';
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

    // Step 2: Subscribe to Supabase real-time stream with automatic reconnection
    var shouldReconnect = true;
    while (shouldReconnect) {
      try {
        await for (final data in _supabase
            .from('sticky_notes')
            .stream(primaryKey: ['id'])
            .eq('pair_id', pairId)
            .order('created_at', ascending: false)) {
          print('StickyNotesRepository: Stream emitted ${data.length} notes');

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

          // Convert to StickyNote objects
          final notes = notesWithNames
              .map((json) => StickyNote.fromJson(json))
              .toList();

          // Cache all notes
          await _dbService.saveStickyNotes(notes);
          print('StickyNotesRepository: Updated cache with ${notes.length} notes');

          yield notes;
        }
      } catch (error) {
        print('StickyNotesRepository: Stream error (likely offline): $error');
        print('StickyNotesRepository: Will retry connection in 5 seconds...');

        // Wait before retrying
        await Future.delayed(const Duration(seconds: 5));
        print('StickyNotesRepository: Attempting to reconnect...');
      }
    }
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
}
