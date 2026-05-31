import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _instance;
  static const String _dbName = 'swingtell.db';
  static const int _dbVersion = 1;

  static Future<Database> get database async {
    if (_instance != null) return _instance!;
    _instance = await _initDatabase();
    return _instance!;
  }

  static Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(dir.path, 'database'));
    if (!await dbDir.exists()) await dbDir.create(recursive: true);
    final path = p.join(dbDir.path, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT DEFAULT '',
        file_path TEXT NOT NULL UNIQUE,
        file_format TEXT NOT NULL,
        file_size INTEGER DEFAULT 0,
        cover_path TEXT,
        total_chapters INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        idx INTEGER NOT NULL,
        title TEXT DEFAULT '',
        source TEXT DEFAULT 'format',
        start_pos INTEGER DEFAULT 0,
        end_pos INTEGER DEFAULT 0,
        char_count INTEGER DEFAULT 0,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_progress (
        book_id TEXT PRIMARY KEY,
        chapter_index INTEGER DEFAULT 0,
        char_offset INTEGER DEFAULT 0,
        total_progress REAL DEFAULT 0.0,
        last_read_at INTEGER NOT NULL,
        total_reading_seconds INTEGER DEFAULT 0,
        ai_recap TEXT,
        pronunciation_version TEXT,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        char_offset INTEGER NOT NULL,
        text_snippet TEXT,
        note TEXT,
        type TEXT DEFAULT 'bookmark',
        color TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_chapters_book ON chapters(book_id, idx)
    ''');
    await db.execute('''
      CREATE INDEX idx_bookmarks_book ON bookmarks(book_id)
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations here
  }

  // --- Books ---

  static Future<int> insertBook(Map<String, dynamic> book) async {
    final db = await database;
    return db.insert('books', book, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getBook(String id) async {
    final db = await database;
    final results = await db.query('books', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<Map<String, dynamic>?> getBookByPath(String filePath) async {
    final db = await database;
    final results = await db.query('books', where: 'file_path = ?', whereArgs: [filePath]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<List<Map<String, dynamic>>> getAllBooks() async {
    final db = await database;
    return db.query('books', orderBy: 'updated_at DESC');
  }

  static Future<List<Map<String, dynamic>>> getRecentBooks({int limit = 20}) async {
    final db = await database;
    return db.rawQuery('''
      SELECT b.*, rp.total_progress, rp.last_read_at as progress_time
      FROM books b
      LEFT JOIN reading_progress rp ON b.id = rp.book_id
      ORDER BY COALESCE(rp.last_read_at, b.updated_at) DESC
      LIMIT ?
    ''', [limit]);
  }

  static Future<int> updateBook(String id, Map<String, dynamic> values) async {
    final db = await database;
    return db.update('books', values, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteBook(String id) async {
    final db = await database;
    await db.delete('chapters', where: 'book_id = ?', whereArgs: [id]);
    await db.delete('reading_progress', where: 'book_id = ?', whereArgs: [id]);
    return db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  // --- Chapters ---

  static Future<void> insertChapters(List<Map<String, dynamic>> chapters) async {
    final db = await database;
    final batch = db.batch();
    for (final ch in chapters) {
      batch.insert('chapters', ch, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getChapters(String bookId) async {
    final db = await database;
    return db.query('chapters', where: 'book_id = ?', whereArgs: [bookId], orderBy: 'idx ASC');
  }

  static Future<Map<String, dynamic>?> getChapter(String bookId, int index) async {
    final db = await database;
    final results = await db.query('chapters',
        where: 'book_id = ? AND idx = ?', whereArgs: [bookId, index]);
    return results.isNotEmpty ? results.first : null;
  }

  // --- Reading Progress ---

  static Future<int> saveProgress(Map<String, dynamic> progress) async {
    final db = await database;
    return db.insert('reading_progress', progress,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getProgress(String bookId) async {
    final db = await database;
    final results =
        await db.query('reading_progress', where: 'book_id = ?', whereArgs: [bookId]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<void> close() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
  }
}
