import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/memory.dart';
import '../models/personality.dart';

/// 数据库服务：SQLite 管理，建表 & CRUD
class DatabaseService {
  static Database? _database;
  static const _dbName = 'cyber_ex.db';
  static const _dbVersion = 2;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE messages ADD COLUMN message_type TEXT DEFAULT 'text'");
      await db.execute(
          'ALTER TABLE messages ADD COLUMN image_base64 TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        message_type TEXT DEFAULT 'text',
        content TEXT DEFAULT '',
        image_base64 TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        content TEXT NOT NULL,
        importance INTEGER DEFAULT 5,
        source_msg_ids TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE personality (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        mode TEXT NOT NULL,
        ex_name TEXT DEFAULT 'TA',
        base_personality TEXT DEFAULT '',
        speaking_style TEXT DEFAULT '',
        backstory TEXT DEFAULT '',
        traits_json TEXT DEFAULT '{}',
        raw_analysis TEXT DEFAULT '',
        updated_at TEXT NOT NULL
      )
    ''');

    // 为查询性能创建索引
    await db.execute(
        'CREATE INDEX idx_messages_session ON messages(session_id, created_at)');
    await db.execute(
        'CREATE INDEX idx_memories_session ON memories(session_id)');
    await db.execute(
        'CREATE INDEX idx_personality_session ON personality(session_id)');
  }

  // ==================== Messages ====================

  Future<int> insertMessage(Message msg) async {
    final db = await database;
    return await db.insert('messages', msg.toMap());
  }

  Future<List<Message>> getMessages(String sessionId,
      {int limit = 200, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Message.fromMap(m)).toList();
  }

  Future<List<Message>> getRecentMessages(String sessionId,
      {int count = 50}) async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT * FROM messages WHERE session_id = ? ORDER BY created_at DESC LIMIT ?',
      [sessionId, count],
    );
    final list = maps.map((m) => Message.fromMap(m)).toList();
    return list.reversed.toList(); // 返回时间正序
  }

  Future<int> getMessageCount(String sessionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM messages WHERE session_id = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Message>> searchMessages(String sessionId, String keyword) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'session_id = ? AND content LIKE ?',
      whereArgs: [sessionId, '%$keyword%'],
      orderBy: 'created_at DESC',
      limit: 100,
    );
    return maps.map((m) => Message.fromMap(m)).toList();
  }

  // ==================== Memories ====================

  Future<int> insertMemory(Memory memory) async {
    final db = await database;
    return await db.insert('memories', memory.toMap());
  }

  Future<List<Memory>> getMemories(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'memories',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'importance DESC, created_at DESC',
    );
    return maps.map((m) => Memory.fromMap(m)).toList();
  }

  Future<List<Memory>> getTopMemories(String sessionId, int count) async {
    final db = await database;
    final maps = await db.query(
      'memories',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'importance DESC',
      limit: count,
    );
    return maps.map((m) => Memory.fromMap(m)).toList();
  }

  Future<int> deleteMemory(int id) async {
    final db = await database;
    return await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getMemoryCount(String sessionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM memories WHERE session_id = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== Personality ====================

  Future<int> insertOrUpdatePersonality(Personality p) async {
    final db = await database;
    // 检查是否已存在
    final existing = await db.query(
      'personality',
      where: 'session_id = ?',
      whereArgs: [p.sessionId],
    );
    if (existing.isNotEmpty) {
      return await db.update(
        'personality',
        p.toMap(),
        where: 'session_id = ?',
        whereArgs: [p.sessionId],
      );
    } else {
      return await db.insert('personality', p.toMap());
    }
  }

  Future<Personality?> getPersonality(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'personality',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    if (maps.isEmpty) return null;
    return Personality.fromMap(maps.first);
  }

  // ==================== 统计 ====================

  Future<Map<String, int>> getStats(String sessionId) async {
    final db = await database;
    final msgCount = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM messages WHERE session_id = ?',
      [sessionId],
    );
    final memCount = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM memories WHERE session_id = ?',
      [sessionId],
    );
    return {
      'messages': Sqflite.firstIntValue(msgCount) ?? 0,
      'memories': Sqflite.firstIntValue(memCount) ?? 0,
    };
  }
}
