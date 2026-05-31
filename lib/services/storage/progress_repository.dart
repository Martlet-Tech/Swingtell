import 'package:sqflite/sqflite.dart';
import '../../models/reading_progress.dart';
import 'database.dart';

class ProgressRepository {
  Future<void> save(ReadingProgress progress) async {
    final db = await DatabaseService.database;
    await db.insert(
      'reading_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReadingProgress?> load(String bookId) async {
    final db = await DatabaseService.database;
    final rows = await db.query(
      'reading_progress',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    if (rows.isEmpty) return null;
    return ReadingProgress.fromMap(rows.first);
  }
}
