import '../../models/chapter.dart';
import '../services/database_service.dart';

/// Chapter 数据仓库
class ChapterRepository {
  ChapterRepository({required DatabaseService db}) : _db = db;
  final DatabaseService _db;

  Future<List<Chapter>> getByBookId(String bookId) async {
    final data = await _db.getChapters(bookId);
    return data.map((m) => Chapter.fromMap(m)).toList();
  }

  Future<Chapter?> getChapter(String bookId, int index) async {
    final data = await _db.getChapter(bookId, index);
    if (data == null) return null;
    return Chapter.fromMap(data);
  }

  Future<void> saveAll(List<Chapter> chapters) async {
    await _db.insertChapters(chapters.map((ch) => ch.toMap()).toList());
  }
}
