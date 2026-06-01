import '../../models/reading_progress.dart';
import '../services/database_service.dart';

/// 阅读进度数据仓库
///
/// 不再直接调 DatabaseService.xxx 静态方法，改为通过注入的 DatabaseService 实例操作。
class ProgressRepository {
  ProgressRepository({required DatabaseService db}) : _db = db;
  final DatabaseService _db;

  Future<void> save(ReadingProgress progress) async {
    await _db.saveProgress(progress.toMap());
  }

  Future<ReadingProgress?> load(String bookId) async {
    final row = await _db.getProgress(bookId);
    if (row == null) return null;
    return ReadingProgress.fromMap(row);
  }
}
