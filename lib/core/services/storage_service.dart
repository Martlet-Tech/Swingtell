import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import '../models/reader_settings.dart';
import '../models/chat_session.dart';

class StorageService {
  late Box<Book> _bookBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(BookAdapter());
    Hive.registerAdapter(ReadingProgressAdapter());
    Hive.registerAdapter(ReaderSettingsAdapter());
    Hive.registerAdapter(ChatSessionAdapter());
    _bookBox = await Hive.openBox<Book>('books');
    await _openOrResetBox<ReadingProgress>('progress');
    await _openOrResetBox<ReaderSettings>('settings');
  }

  Future<Box<T>> _openOrResetBox<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (_) {
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {
        // deleteBoxFromDisk 可能因 .lock 不存在而失败，忽略
      }
      return await Hive.openBox<T>(name);
    }
  }

  Future<Directory> getBooksDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/books');
    if (!await booksDir.exists()) await booksDir.create(recursive: true);
    return booksDir;
  }

  Future<String> importEpubFile(String sourcePath) async {
    final booksDir = await getBooksDirectory();
    final fileName = path.basename(sourcePath);
    final destPath = '${booksDir.path}/$fileName';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  List<Book> getAllBooks() => _bookBox.values.toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  Future<void> saveBook(Book book) => _bookBox.put(book.id, book);

  Future<void> removeBook(String bookId) async {
    final book = _bookBox.get(bookId);
    if (book != null) {
      final file = File(book.filePath);
      if (await file.exists()) await file.delete();
      await _bookBox.delete(bookId);
    }
  }
}
