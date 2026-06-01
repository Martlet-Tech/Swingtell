import '../../models/book.dart';
import '../services/database_service.dart';

/// Book 数据仓库
///
/// 封装所有 Book 相关的数据存取。目前只有 SQLite，
/// 将来接远程 API 时只需在此类背后加数据源即可。
class BookRepository {
  BookRepository({required DatabaseService db}) : _db = db;
  final DatabaseService _db;

  Future<Book?> getById(String id) async {
    final data = await _db.getBook(id);
    if (data == null) return null;
    return Book.fromMap(data);
  }

  Future<Book?> getByPath(String filePath) async {
    final data = await _db.getBookByPath(filePath);
    if (data == null) return null;
    return Book.fromMap(data);
  }

  Future<List<Book>> getAll() async {
    final data = await _db.getAllBooks();
    return data.map((m) => Book.fromMap(m)).toList();
  }

  /// 带阅读进度关联的最近书籍列表
  Future<List<Map<String, dynamic>>> getRecentBooks({int limit = 20}) async {
    return _db.getRecentBooks(limit: limit);
  }

  Future<void> save(Book book) async {
    await _db.insertBook(book.toMap());
  }

  Future<void> update(String id, Map<String, dynamic> values) async {
    await _db.updateBook(id, values);
  }

  Future<void> delete(String id) async {
    await _db.deleteBook(id);
  }
}
