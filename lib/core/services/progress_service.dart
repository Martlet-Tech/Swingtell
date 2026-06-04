import 'package:hive/hive.dart';
import '../models/reading_progress.dart';

class ProgressService {
  late Box<ReadingProgress> _box;

  Future<void> init() async {
    _box = await Hive.openBox<ReadingProgress>('progress');
  }

  ReadingProgress getProgress(String bookId) {
    return _box.get(bookId) ??
        (ReadingProgress()
          ..bookId = bookId
          ..chapterIndex = 0
          ..charOffset = 0
          ..percentage = 0.0
          ..updatedAt = DateTime.now());
  }

  Future<void> saveProgress(ReadingProgress progress) async {
    progress.updatedAt = DateTime.now();
    await _box.put(progress.bookId, progress);
  }

  Map<String, ReadingProgress> getAllProgress() {
    return {for (final p in _box.values) p.bookId: p};
  }
}
