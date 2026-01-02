import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/models/sticky_note.dart';

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
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        display_name TEXT,
        avatar_url TEXT,
        pair_id TEXT,
        fcm_token TEXT,
        device_id TEXT,
        status TEXT,
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
        is_liked INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        cached_at INTEGER NOT NULL
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

    print('Database tables created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Database upgrade from version $oldVersion to $newVersion');
    // Future migrations will be handled here
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
        'avatar_url': user.avatarUrl,
        'pair_id': user.pairId,
        'fcm_token': user.fcmToken,
        'device_id': user.deviceId,
        'status': user.status,
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
      avatarUrl: data['avatar_url'],
      pairId: data['pair_id'],
      fcmToken: data['fcm_token'],
      deviceId: data['device_id'],
      status: data['status'],
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
      avatarUrl: data['avatar_url'],
      pairId: data['pair_id'],
      fcmToken: data['fcm_token'],
      deviceId: data['device_id'],
      status: data['status'],
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
        'is_liked': note.isLiked ? 1 : 0,
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
          'is_liked': note.isLiked ? 1 : 0,
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
      return StickyNote(
        id: data['id'],
        pairId: data['pair_id'],
        senderId: data['sender_id'],
        senderName: data['sender_name'],
        message: data['message'],
        isLiked: data['is_liked'] == 1,
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

  // Clear all data
  Future<void> clearAllData() async {
    await clearAllUsers();
    await clearAllStickyNotes();
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
