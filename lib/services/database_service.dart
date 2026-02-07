import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/models/sticky_note.dart';
import 'package:twain/models/sticky_note_reply.dart';
import 'package:twain/models/wallpaper.dart';
import 'package:twain/models/shared_board_photo.dart';
import 'package:twain/models/user_location.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'twain.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        display_name TEXT,
        nickname TEXT,
        avatar_url TEXT,
        pair_id TEXT,
        fcm_token TEXT,
        device_id TEXT,
        status TEXT,
        last_active_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        preferences TEXT,
        metadata TEXT,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Create sticky_notes table
    await db.execute('''
      CREATE TABLE sticky_notes (
        id TEXT PRIMARY KEY,
        pair_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT,
        message TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT 'FFF9C4',
        liked_by_user_ids TEXT NOT NULL DEFAULT '[]',
        reply_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Create sticky_note_replies table
    await db.execute('''
      CREATE TABLE sticky_note_replies (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        FOREIGN KEY (note_id) REFERENCES sticky_notes(id) ON DELETE CASCADE
      )
    ''');

    // Create wallpapers table
    await db.execute('''
      CREATE TABLE wallpapers (
        id TEXT PRIMARY KEY,
        pair_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        image_url TEXT NOT NULL,
        source_type TEXT NOT NULL,
        apply_to TEXT NOT NULL,
        status TEXT NOT NULL,
        applied_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Create shared_board_photos table
    await db.execute('''
      CREATE TABLE shared_board_photos (
        id TEXT PRIMARY KEY,
        pair_id TEXT NOT NULL,
        uploader_id TEXT NOT NULL,
        image_url TEXT NOT NULL,
        thumbnail_url TEXT,
        file_size INTEGER NOT NULL,
        mime_type TEXT NOT NULL,
        width INTEGER,
        height INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    // Create user_locations table
    await db.execute('''
      CREATE TABLE user_locations (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        pair_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        recorded_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create metadata table
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_users_pair_id ON users(pair_id)');
    await db.execute('CREATE INDEX idx_sticky_notes_pair_id ON sticky_notes(pair_id)');
    await db.execute('CREATE INDEX idx_sticky_notes_created_at ON sticky_notes(created_at DESC)');
    await db.execute('CREATE INDEX idx_sticky_note_replies_note_id ON sticky_note_replies(note_id)');
    await db.execute('CREATE INDEX idx_sticky_note_replies_created_at ON sticky_note_replies(created_at ASC)');
    await db.execute('CREATE INDEX idx_wallpapers_pair_id ON wallpapers(pair_id)');
    await db.execute('CREATE INDEX idx_wallpapers_created_at ON wallpapers(created_at DESC)');
    await db.execute('CREATE INDEX idx_shared_board_photos_pair_id ON shared_board_photos(pair_id)');
    await db.execute('CREATE INDEX idx_shared_board_photos_created_at ON shared_board_photos(created_at DESC)');
    await db.execute('CREATE INDEX idx_user_locations_pair_id ON user_locations(pair_id)');
    await db.execute('CREATE INDEX idx_user_locations_recorded_at ON user_locations(recorded_at DESC)');

    print('Database tables created successfully');
  }

  // User operations
  Future<void> saveUser(TwainUser user) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'users',
      {
        'id': user.id,
        'email': user.email,
        'display_name': user.displayName,
        'nickname': user.nickname,
        'avatar_url': user.avatarUrl,
        'pair_id': user.pairId,
        'fcm_token': user.fcmToken,
        'device_id': user.deviceId,
        'status': user.status,
        'last_active_at': user.lastActiveAt?.toIso8601String(),
        'created_at': user.createdAt.toIso8601String(),
        'updated_at': user.updatedAt.toIso8601String(),
        'preferences': user.preferences != null ? jsonEncode(user.preferences) : null,
        'metadata': user.metaData != null ? jsonEncode(user.metaData) : null,
        'cached_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('User ${user.id} saved to database');
  }

  Future<TwainUser?> getUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (results.isEmpty) return null;

    final data = results.first;
    return TwainUser(
      id: data['id'],
      email: data['email'],
      displayName: data['display_name'],
      nickname: data['nickname'],
      avatarUrl: data['avatar_url'],
      pairId: data['pair_id'],
      fcmToken: data['fcm_token'],
      deviceId: data['device_id'],
      status: data['status'],
      lastActiveAt: data['last_active_at'] != null
          ? DateTime.tryParse(data['last_active_at'])
          : null,
      createdAt: DateTime.parse(data['created_at']),
      updatedAt: DateTime.parse(data['updated_at']),
      preferences: data['preferences'] != null ? jsonDecode(data['preferences']) : null,
      metaData: data['metadata'] != null ? jsonDecode(data['metadata']) : null,
    );
  }

  Future<TwainUser?> getUserByPairId(String pairId, String excludeUserId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'pair_id = ? AND id != ?',
      whereArgs: [pairId, excludeUserId],
    );

    if (results.isEmpty) return null;

    final data = results.first;
    return TwainUser(
      id: data['id'],
      email: data['email'],
      displayName: data['display_name'],
      nickname: data['nickname'],
      avatarUrl: data['avatar_url'],
      pairId: data['pair_id'],
      fcmToken: data['fcm_token'],
      deviceId: data['device_id'],
      status: data['status'],
      lastActiveAt: data['last_active_at'] != null
          ? DateTime.tryParse(data['last_active_at'])
          : null,
      createdAt: DateTime.parse(data['created_at']),
      updatedAt: DateTime.parse(data['updated_at']),
      preferences: data['preferences'] != null ? jsonDecode(data['preferences']) : null,
      metaData: data['metadata'] != null ? jsonDecode(data['metadata']) : null,
    );
  }

  Future<void> deleteUser(String userId) async {
    final db = await database;
    await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    print('User $userId deleted from database');
  }

  Future<void> clearAllUsers() async {
    final db = await database;
    await db.delete('users');
    print('All users cleared from database');
  }

  // Sticky notes operations
  Future<void> saveStickyNote(StickyNote note) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'sticky_notes',
      {
        'id': note.id,
        'pair_id': note.pairId,
        'sender_id': note.senderId,
        'sender_name': note.senderName,
        'message': note.message,
        'color': note.color,
        'liked_by_user_ids': jsonEncode(note.likedByUserIds),
        'reply_count': note.replyCount,
        'created_at': note.createdAt.toIso8601String(),
        'updated_at': note.updatedAt.toIso8601String(),
        'cached_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveStickyNotes(List<StickyNote> notes) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final note in notes) {
      batch.insert(
        'sticky_notes',
        {
          'id': note.id,
          'pair_id': note.pairId,
          'sender_id': note.senderId,
          'sender_name': note.senderName,
          'message': note.message,
          'color': note.color,
          'liked_by_user_ids': jsonEncode(note.likedByUserIds),
          'reply_count': note.replyCount,
          'created_at': note.createdAt.toIso8601String(),
          'updated_at': note.updatedAt.toIso8601String(),
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${notes.length} sticky notes saved to database');
  }

  Future<List<StickyNote>> getStickyNotesByPairId(String pairId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'sticky_notes',
      where: 'pair_id = ?',
      whereArgs: [pairId],
      orderBy: 'created_at DESC',
    );

    return results.map((data) {
      List<String> likedByUserIds = [];
      try {
        final likedByJson = data['liked_by_user_ids'] as String;
        likedByUserIds = List<String>.from(jsonDecode(likedByJson) as List);
      } catch (e) {
        print('Error parsing liked_by_user_ids: $e');
      }

      return StickyNote(
        id: data['id'],
        pairId: data['pair_id'],
        senderId: data['sender_id'],
        senderName: data['sender_name'],
        message: data['message'],
        color: data['color'] ?? 'FFF9C4',
        likedByUserIds: likedByUserIds,
        replyCount: data['reply_count'] ?? 0,
        createdAt: DateTime.parse(data['created_at']),
        updatedAt: DateTime.parse(data['updated_at']),
      );
    }).toList();
  }

  Future<void> deleteStickyNote(String noteId) async {
    final db = await database;
    await db.delete(
      'sticky_notes',
      where: 'id = ?',
      whereArgs: [noteId],
    );
    print('Sticky note $noteId deleted from database');
  }

  Future<void> clearStickyNotesByPairId(String pairId) async {
    final db = await database;
    await db.delete(
      'sticky_notes',
      where: 'pair_id = ?',
      whereArgs: [pairId],
    );
    print('Sticky notes for pair $pairId cleared from database');
  }

  Future<void> clearAllStickyNotes() async {
    final db = await database;
    await db.delete('sticky_notes');
    print('All sticky notes cleared from database');
  }

  // Sticky note replies operations
  Future<void> saveStickyNoteReply(StickyNoteReply reply) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'sticky_note_replies',
      {
        'id': reply.id,
        'note_id': reply.noteId,
        'sender_id': reply.senderId,
        'sender_name': reply.senderName,
        'message': reply.message,
        'created_at': reply.createdAt.toIso8601String(),
        'updated_at': reply.updatedAt.toIso8601String(),
        'cached_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveStickyNoteReplies(List<StickyNoteReply> replies) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final reply in replies) {
      batch.insert(
        'sticky_note_replies',
        {
          'id': reply.id,
          'note_id': reply.noteId,
          'sender_id': reply.senderId,
          'sender_name': reply.senderName,
          'message': reply.message,
          'created_at': reply.createdAt.toIso8601String(),
          'updated_at': reply.updatedAt.toIso8601String(),
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${replies.length} sticky note replies saved to database');
  }

  Future<List<StickyNoteReply>> getRepliesByNoteId(String noteId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'sticky_note_replies',
      where: 'note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at ASC',
    );

    return results.map((data) {
      return StickyNoteReply(
        id: data['id'],
        noteId: data['note_id'],
        senderId: data['sender_id'],
        senderName: data['sender_name'],
        message: data['message'],
        createdAt: DateTime.parse(data['created_at']),
        updatedAt: DateTime.parse(data['updated_at']),
      );
    }).toList();
  }

  Future<void> deleteStickyNoteReply(String replyId) async {
    final db = await database;
    await db.delete(
      'sticky_note_replies',
      where: 'id = ?',
      whereArgs: [replyId],
    );
    print('Sticky note reply $replyId deleted from database');
  }

  Future<void> clearRepliesByNoteId(String noteId) async {
    final db = await database;
    await db.delete(
      'sticky_note_replies',
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
    print('Replies for note $noteId cleared from database');
  }

  // Metadata operations
  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'metadata',
      {
        'key': key,
        'value': value,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMetadata(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  // Wallpaper operations
  Future<void> saveWallpapers(List<Wallpaper> wallpapers) async {
    final db = await database;
    final batch = db.batch();

    for (final wallpaper in wallpapers) {
      batch.insert(
        'wallpapers',
        wallpaper.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${wallpapers.length} wallpapers saved to database');
  }

  Future<List<Wallpaper>> getWallpapersByPairId(String pairId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'wallpapers',
      where: 'pair_id = ?',
      whereArgs: [pairId],
      orderBy: 'created_at DESC',
    );

    return results.map((map) => Wallpaper.fromDatabase(map)).toList();
  }

  Future<void> updateWallpaperStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'wallpapers',
      {
        'status': status,
        'applied_at': status == 'applied' ? DateTime.now().toIso8601String() : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearWallpapers() async {
    final db = await database;
    await db.delete('wallpapers');
    print('All wallpapers cleared from database');
  }

  // Shared board photos operations
  Future<void> saveSharedBoardPhotos(List<SharedBoardPhoto> photos) async {
    final db = await database;
    final batch = db.batch();

    for (final photo in photos) {
      batch.insert(
        'shared_board_photos',
        photo.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${photos.length} shared board photos saved to database');
  }

  Future<List<SharedBoardPhoto>> getSharedBoardPhotosByPairId(String pairId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'shared_board_photos',
      where: 'pair_id = ?',
      whereArgs: [pairId],
      orderBy: 'created_at DESC',
    );

    return results.map((map) => SharedBoardPhoto.fromDatabase(map)).toList();
  }

  Future<void> deleteSharedBoardPhoto(String id) async {
    final db = await database;
    await db.delete(
      'shared_board_photos',
      where: 'id = ?',
      whereArgs: [id],
    );
    print('Shared board photo $id deleted from database');
  }

  Future<void> clearSharedBoardPhotos() async {
    final db = await database;
    await db.delete('shared_board_photos');
    print('All shared board photos cleared from database');
  }

  // User locations operations
  Future<void> saveUserLocations(List<UserLocation> locations) async {
    if (locations.isEmpty) return;

    final db = await database;
    final batch = db.batch();

    for (final location in locations) {
      batch.insert(
        'user_locations',
        location.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${locations.length} user locations saved to database');
  }

  Future<List<UserLocation>> getUserLocationsByPairId(String pairId) async {
    final db = await database;
    final results = await db.query(
      'user_locations',
      where: 'pair_id = ?',
      whereArgs: [pairId],
      orderBy: 'recorded_at DESC',
    );

    final byUser = <String, UserLocation>{};
    for (final row in results) {
      final userId = row['user_id'] as String?;
      if (userId == null) continue;
      if (byUser.containsKey(userId)) continue;
      try {
        byUser[userId] = UserLocation.fromDatabase(row);
      } catch (error) {
        print('DatabaseService.getUserLocationsByPairId parse error: $error');
      }
    }

    return byUser.values.toList();
  }

  Future<void> clearUserLocationsByPairId(String pairId) async {
    final db = await database;
    await db.delete(
      'user_locations',
      where: 'pair_id = ?',
      whereArgs: [pairId],
    );
  }

  Future<void> clearAllUserLocations() async {
    final db = await database;
    await db.delete('user_locations');
  }

  // Clear all data
  Future<void> clearAllData() async {
    await clearAllUsers();
    await clearAllStickyNotes();
    await clearAllUserLocations();
    final db = await database;
    await db.delete('metadata');
    print('All database data cleared');
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
    print('Database closed');
  }
}
